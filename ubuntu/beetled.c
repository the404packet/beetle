#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <sys/select.h>

#define SOCKET_PATH "/var/run/beetle.sock"
#define HANDLER     "/usr/local/bin/beetled-handler"
#define BUFFER_SIZE 4096

/* Relay bytes from `from_fd` to `to_fd` until EOF on `from_fd`.
 * Returns 0 on EOF, -1 on error. */
static int relay_once(int from_fd, int to_fd)
{
    char buf[BUFFER_SIZE];
    ssize_t n = read(from_fd, buf, sizeof(buf));
    if (n < 0) return -1;
    if (n == 0) return 0;

    ssize_t off = 0;
    while (off < n) {
        ssize_t w = write(to_fd, buf + off, (size_t)(n - off));
        if (w <= 0) return -1;
        off += w;
    }
    return 1;  /* keep going */
}

static void handle_client(int client_fd)
{
    char buffer[BUFFER_SIZE] = {0};

    int n = read(client_fd, buffer, sizeof(buffer) - 1);
    if (n <= 0) {
        close(client_fd);
        return;
    }
    buffer[n] = '\0';

    /* Extract user= from request */
    char real_user[64] = "unknown";
    char *user_start = strstr(buffer, "user=");
    if (user_start) {
        user_start += 5;
        char *end = strchr(user_start, ' ');
        if (end) {
            size_t len = (size_t)(end - user_start);
            if (len < sizeof(real_user)) {
                strncpy(real_user, user_start, len);
                real_user[len] = '\0';
            }
        }
    }

    printf("Resolved USER=%s\n", real_user);
    fflush(stdout);

    /* Three pipes:
     *   request_pipe : daemon -> handler stdin (request bytes)
     *   output_pipe  : handler stdout/stderr -> daemon -> client
     *   answer_pipe  : daemon -> handler fd 4 (interactive answers)
     */
    int request_pipe[2];
    int output_pipe[2];
    int answer_pipe[2];

    if (pipe(request_pipe) < 0 || pipe(output_pipe) < 0 ||
        pipe(answer_pipe) < 0) {
        perror("pipe");
        close(client_fd);
        return;
    }

    pid_t pid = fork();
    if (pid < 0) {
        perror("fork");
        close(client_fd);
        return;
    }

    if (pid == 0) {
        /* --- Child: handler setup --- */
        close(request_pipe[1]);
        close(output_pipe[0]);
        close(answer_pipe[1]);

        dup2(request_pipe[0], STDIN_FILENO);
        dup2(output_pipe[1],  STDOUT_FILENO);
        dup2(output_pipe[1],  STDERR_FILENO);
        dup2(answer_pipe[0],  4);   /* fd 4 = interactive answers */

        close(request_pipe[0]);
        close(output_pipe[1]);
        close(answer_pipe[0]);

        setenv("BEETLE_USER", real_user, 1);
        setenv("BEETLE_INTERACTIVE", "1", 1);

        execl(HANDLER, "beetled-handler", NULL);
        perror("exec failed");
        _exit(1);
    }

    /* --- Parent --- */
    close(request_pipe[0]);
    close(output_pipe[1]);
    close(answer_pipe[0]);

    /* Send the request, then close so handler's stdin sees EOF. */
    if (write(request_pipe[1], buffer, strlen(buffer)) < 0) {
        perror("write request");
    }
    close(request_pipe[1]);

    /* Multiplex:
     *   - client_fd readable  -> forward bytes to handler's fd 4 (answer_pipe[1])
     *   - output_pipe readable -> forward bytes to client_fd
     * Both are bidirectional until either end closes.
     */
    int client_alive = 1;
    int output_alive = 1;

    while (output_alive) {
        fd_set rfds;
        FD_ZERO(&rfds);
        int maxfd = -1;

        if (client_alive) {
            FD_SET(client_fd, &rfds);
            if (client_fd > maxfd) maxfd = client_fd;
        }
        FD_SET(output_pipe[0], &rfds);
        if (output_pipe[0] > maxfd) maxfd = output_pipe[0];

        int ret = select(maxfd + 1, &rfds, NULL, NULL, NULL);
        if (ret < 0) {
            if (errno == EINTR) continue;
            perror("select");
            break;
        }

        if (client_alive && FD_ISSET(client_fd, &rfds)) {
            int r = relay_once(client_fd, answer_pipe[1]);
            if (r <= 0) {
                /* client gone; close answer channel so handler gets EOF
                 * if it tries to prompt again */
                close(answer_pipe[1]);
                answer_pipe[1] = -1;
                client_alive = 0;
            }
        }

        if (FD_ISSET(output_pipe[0], &rfds)) {
            int r = relay_once(output_pipe[0], client_fd);
            if (r <= 0) {
                /* handler closed stdout -> script is done */
                output_alive = 0;
            }
        }
    }

    if (answer_pipe[1] >= 0) close(answer_pipe[1]);
    close(output_pipe[0]);

    waitpid(pid, NULL, 0);
    close(client_fd);
}

int main(void)
{
    int server_fd, client_fd;
    struct sockaddr_un addr;

    signal(SIGPIPE, SIG_IGN);

    unlink(SOCKET_PATH);

    server_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("socket failed");
        exit(1);
    }

    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

    if (bind(server_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind failed");
        exit(1);
    }

    chmod(SOCKET_PATH, 0600);

    if (listen(server_fd, 10) < 0) {
        perror("listen failed");
        exit(1);
    }

    printf("Beetle daemon started...\n");
    fflush(stdout);

    while (1) {
        client_fd = accept(server_fd, NULL, NULL);
        if (client_fd < 0) {
            if (errno == EINTR) continue;
            perror("accept failed");
            continue;
        }

        pid_t pid = fork();
        if (pid == 0) {
            close(server_fd);
            handle_client(client_fd);
            _exit(0);
        } else if (pid > 0) {
            close(client_fd);
            waitpid(-1, NULL, WNOHANG);
        } else {
            perror("fork failed");
            close(client_fd);
        }
    }

    close(server_fd);
    unlink(SOCKET_PATH);
    return 0;
}
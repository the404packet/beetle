#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/stat.h>

#define SOCKET_PATH "/var/run/beetle.sock"
#define HANDLER "/usr/local/bin/beetled-handler"
#define BUFFER_SIZE 1024

void handle_client(int client_fd)
{
    char buffer[BUFFER_SIZE] = {0};

    int n = read(client_fd, buffer, sizeof(buffer) - 1);
    if (n <= 0)
    {
        close(client_fd);
        return;
    }

    buffer[n] = '\0';

    char real_user[64] = "unknown";

    char *user_start = strstr(buffer, "user=");
    if (user_start)
    {
        user_start += 5;
        char *end = strchr(user_start, ' ');
        if (end)
        {
            size_t len = end - user_start;
            if (len < sizeof(real_user))
            {
                strncpy(real_user, user_start, len);
                real_user[len] = '\0';
            }
        }
    }

    printf("Resolved USER=%s\n", real_user);

    int pipefd[2];
    if (pipe(pipefd) < 0)
    {
        perror("pipe failed");
        close(client_fd);
        return;
    }

    pid_t pid = fork();

    if (pid == 0)
    {
        close(pipefd[1]);

        dup2(pipefd[0], STDIN_FILENO);
        dup2(client_fd, STDOUT_FILENO);
        dup2(client_fd, STDERR_FILENO);

        close(pipefd[0]);
        close(client_fd);

        setenv("BEETLE_USER", real_user, 1);

        execl(HANDLER, "beetled-handler", NULL);

        perror("exec failed");
        exit(1);
    }
    else if (pid > 0)
    {
        close(pipefd[0]);

        write(pipefd[1], buffer, strlen(buffer));
        close(pipefd[1]);

        waitpid(pid, NULL, 0);
        close(client_fd);
    }
    else
    {
        perror("fork failed");
        close(client_fd);
    }
}

int main()
{
    int server_fd, client_fd;
    struct sockaddr_un addr;

    unlink(SOCKET_PATH);

    server_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (server_fd < 0)
    {
        perror("socket failed");
        exit(1);
    }

    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

    if (bind(server_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0)
    {
        perror("bind failed");
        exit(1);
    }

    chmod(SOCKET_PATH, 0600);

    if (listen(server_fd, 10) < 0)
    {
        perror("listen failed");
        exit(1);
    }

    printf("Beetle daemon started...\n");

    while (1)
    {
        client_fd = accept(server_fd, NULL, NULL);
        if (client_fd < 0)
        {
            perror("accept failed");
            continue;
        }

        pid_t pid = fork();
        if (pid == 0)
        {
            close(server_fd);
            handle_client(client_fd);
            exit(0);
        }
        else if (pid > 0)
        {
            close(client_fd);
            waitpid(-1, NULL, WNOHANG);
        }
        else
        {
            perror("fork failed");
            close(client_fd);
        }
    }

    close(server_fd);
    unlink(SOCKET_PATH);
    return 0;
}
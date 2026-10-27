#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <ctype.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/select.h>
#include <pwd.h>

#define SOCKET_PATH "/var/run/beetle.sock"
#define BUFFER_SIZE 4096
#define LINE_MAX_LEN 8192

/* Send exactly n bytes; returns 0 on success, -1 on error */
static int send_all(int fd, const char *buf, size_t n)
{
    size_t sent = 0;
    while (sent < n) {
        ssize_t r = write(fd, buf + sent, n - sent);
        if (r <= 0) return -1;
        sent += (size_t)r;
    }
    return 0;
}

/*
 * Read the daemon's response stream line-by-line.
 *   - Lines starting with "PROMPT:" are prompts: display them, read a
 *     y/n answer from the user's terminal, and send "ANSWER:<y|n>\n" back.
 *   - All other bytes are forwarded verbatim to stdout.
 *   - A carry-over buffer handles lines split across read() boundaries.
 */
static int process_response_stream(int sock)
{
    char rbuf[BUFFER_SIZE];
    char line[LINE_MAX_LEN];
    size_t line_len = 0;

    while (1) {
        ssize_t n = read(sock, rbuf, sizeof(rbuf));
        if (n < 0) {
            perror("read");
            return -1;
        }
        if (n == 0) {
            /* EOF. Flush any partial line. */
            if (line_len > 0) {
                fwrite(line, 1, line_len, stdout);
                fflush(stdout);
            }
            return 0;
        }

        for (ssize_t i = 0; i < n; i++) {
            char c = rbuf[i];

            if (line_len < sizeof(line) - 1)
                line[line_len++] = c;

            if (c == '\n' || line_len == sizeof(line) - 1) {
                line[line_len] = '\0';

                if (strncmp(line, "PROMPT:", 7) == 0) {
                    /* Extract prompt text (strip trailing \n) */
                    char *text = line + 7;
                    char *nl = strchr(text, '\n');
                    if (nl) *nl = '\0';

                    /* Write prompt + flush so the user sees it before we block */
                    fprintf(stdout, "%s [y/n]: ", text);
                    fflush(stdout);

                    char ans_buf[32];
                    if (fgets(ans_buf, sizeof(ans_buf), stdin)) {
                        char c0 = (char)tolower((unsigned char)ans_buf[0]);
                        char ans = (c0 == 'n') ? 'n' : 'y';
                        char out[32];
                        int outlen = snprintf(out, sizeof(out),
                                              "ANSWER:%c\n", ans);
                        if (send_all(sock, out, (size_t)outlen) < 0) {
                            return -1;
                        }
                    } else {
                        /* stdin closed or failed → assume default */
                        if (send_all(sock, "ANSWER:y\n", 9) < 0)
                            return -1;
                    }
                } else {
                    /* Regular output */
                    fwrite(line, 1, line_len, stdout);
                    fflush(stdout);
                }

                line_len = 0;
            }
        }
    }
}

int main(int argc, char *argv[])
{
    int sock;
    struct sockaddr_un addr;

    /* Don't die on EPIPE if the daemon closes first */
    signal(SIGPIPE, SIG_IGN);

    if (argc < 2) {
        printf("Usage: beetle <command>\n");
        return 1;
    }

    const char *user = getenv("SUDO_USER");
    if (!user) {
        struct passwd *pw = getpwuid(getuid());
        user = pw ? pw->pw_name : "unknown";
    }

    char cmd[BUFFER_SIZE] = {0};
    for (int i = 1; i < argc; i++) {
        strncat(cmd, argv[i], sizeof(cmd) - strlen(cmd) - 1);
        if (i != argc - 1)
            strncat(cmd, " ", sizeof(cmd) - strlen(cmd) - 1);
    }

    sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("socket");
        return 1;
    }

    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

    if (connect(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("connect (is beetled running?)");
        close(sock);
        return 1;
    }

    int needed = snprintf(NULL, 0, "user=%s cmd=\"%s\"\n", user, cmd);
    if (needed < 0) {
        perror("snprintf");
        close(sock);
        return 1;
    }

    char *request = malloc((size_t)needed + 1);
    if (!request) {
        perror("malloc");
        close(sock);
        return 1;
    }

    snprintf(request, (size_t)needed + 1,
             "user=%s cmd=\"%s\"\n", user, cmd);

    if (send_all(sock, request, strlen(request)) < 0) {
        perror("write");
        free(request);
        close(sock);
        return 1;
    }
    free(request);

    int rc = process_response_stream(sock);

    close(sock);
    return rc == 0 ? 0 : 1;
}
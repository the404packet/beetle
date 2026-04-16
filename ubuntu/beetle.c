#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <pwd.h>

#define SOCKET_PATH "/var/run/beetle.sock"
#define BUFFER_SIZE 1024

int main(int argc, char *argv[])
{
    int sock;
    struct sockaddr_un addr;
    char buffer[BUFFER_SIZE];

    if (argc < 2)
    {
        printf("Usage: beetle <command>\n");
        return 1;
    }

    // ✅ Get actual user
    struct passwd *pw = getpwuid(getuid());
    const char *user = pw ? pw->pw_name : "unknown";

    // Create socket
    sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0)
    {
        perror("socket");
        return 1;
    }

    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

    if (connect(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0)
    {
        perror("connect (is beetled running?)");
        close(sock);
        return 1;
    }

    char cmd[BUFFER_SIZE] = {0};
    for (int i = 1; i < argc; i++)
    {
        strncat(cmd, argv[i], BUFFER_SIZE - strlen(cmd) - 1);
        if (i != argc - 1)
            strncat(cmd, " ", BUFFER_SIZE - strlen(cmd) - 1);
    }

    char request[BUFFER_SIZE];
    snprintf(request, sizeof(request),
             "user=%s cmd=\"%s\"\n",
             user, cmd);

    // Send request
    if (write(sock, request, strlen(request)) < 0)
    {
        perror("write");
        close(sock);
        return 1;
    }

    // Read response
    int n;
    while ((n = read(sock, buffer, BUFFER_SIZE - 1)) > 0)
    {
        buffer[n] = '\0';
        printf("%s", buffer);
    }

    close(sock);
    return 0;
}
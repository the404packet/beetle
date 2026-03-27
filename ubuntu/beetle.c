#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

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

    char command[BUFFER_SIZE] = {0};

    for (int i = 1; i < argc; i++)
    {
        strncat(command, argv[i], BUFFER_SIZE - strlen(command) - 1);
        if (i != argc - 1)
            strncat(command, " ", BUFFER_SIZE - strlen(command) - 1);
    }

    strncat(command, "\n", BUFFER_SIZE - strlen(command) - 1);

    if (write(sock, command, strlen(command)) < 0)
    {
        perror("write");
        close(sock);
        return 1;
    }

    int n;
    while ((n = read(sock, buffer, BUFFER_SIZE - 1)) > 0)
    {
        buffer[n] = '\0';
        printf("%s", buffer);
    }

    close(sock);
    return 0;
}
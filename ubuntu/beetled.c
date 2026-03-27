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

void handle_client(int client_fd) {
    pid_t pid = fork();

    if (pid == 0) {
        // CHILD

        dup2(client_fd, STDIN_FILENO);
        dup2(client_fd, STDOUT_FILENO);
        dup2(client_fd, STDERR_FILENO);

        close(client_fd);

        execl("/usr/local/bin/beetled-handler", "beetled-handler", NULL);

        perror("exec failed");
        exit(1);
    } else if (pid > 0) {
        // PARENT: wait for child to finish
        waitpid(pid, NULL, 0);
        close(client_fd);   // <-- IMPORTANT: close AFTER child finishes
    } else {
        perror("fork failed");
        close(client_fd);
    }
}

int main() {
    int server_fd, client_fd;
    struct sockaddr_un addr;

    unlink(SOCKET_PATH);

    server_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("socket failed");
        exit(1);
    }

    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_PATH, sizeof(addr.sun_path) - 1);

    if (bind(server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("bind failed");
        exit(1);
    }

    chmod(SOCKET_PATH, 0666);

    if (listen(server_fd, 10) < 0) {
        perror("listen failed");
        exit(1);
    }

    printf("Beetle daemon started...\n");

    while (1) {
        client_fd = accept(server_fd, NULL, NULL);
        if (client_fd < 0) {
            perror("accept failed");
            continue;
        }

        handle_client(client_fd);
    }

    close(server_fd);
    unlink(SOCKET_PATH);
    return 0;
}
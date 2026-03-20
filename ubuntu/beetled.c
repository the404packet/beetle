#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <errno.h>

#define SOCKET_PATH "/var/run/beetle.sock"
#define BASE_DIR "/usr/local/bin/beetle_shell"
#define BUFFER_SIZE 1024

void handle_client(int client_fd) {
    char buffer[BUFFER_SIZE];
    memset(buffer, 0, BUFFER_SIZE);

    int n = read(client_fd, buffer, BUFFER_SIZE - 1);
    if (n <= 0) {
        close(client_fd);
        exit(1);
    }

    buffer[n] = '\0';

    // Remove newline
    buffer[strcspn(buffer, "\n")] = 0;

    // Parse command
    char *args[64];
    int i = 0;

    char *token = strtok(buffer, " ");
    while (token != NULL && i < 63) {
        args[i++] = token;
        token = strtok(NULL, " ");
    }
    args[i] = NULL;

    if (i == 0) {
        write(client_fd, "Invalid command\n", 16);
        close(client_fd);
        exit(1);
    }

    char script_path[512];
    snprintf(script_path, sizeof(script_path), "%s/%s.sh", BASE_DIR, args[0]);

    // Security: validate command name
    for (int j = 0; args[0][j]; j++) {
        if (!( (args[0][j] >= 'a' && args[0][j] <= 'z') ||
               (args[0][j] >= 'A' && args[0][j] <= 'Z') ||
               (args[0][j] >= '0' && args[0][j] <= '9') ||
               args[0][j] == '-' || args[0][j] == '_' )) {
            write(client_fd, "Invalid command\n", 16);
            close(client_fd);
            exit(1);
        }
    }

    // Redirect output to socket
    dup2(client_fd, STDOUT_FILENO);
    dup2(client_fd, STDERR_FILENO);

    // Execute script
    execv(script_path, args);

    // If exec fails
    perror("execv failed");
    exit(1);
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

    // Permissions: rw for owner + group
    chmod(SOCKET_PATH, 0660);

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

        pid_t pid = fork();

        if (pid == 0) {
            // Child
            close(server_fd);
            handle_client(client_fd);
        } else if (pid > 0) {
            // Parent
            close(client_fd);
            waitpid(-1, NULL, WNOHANG); // prevent zombies
        } else {
            perror("fork failed");
            close(client_fd);
        }
    }

    close(server_fd);
    unlink(SOCKET_PATH);
    return 0;
}
#include <unistd.h>

const char *WRAPPED_PROGRAM = "/usr/local/bin/checkout-and-index";

int main(int argc, char *argv[])
{
    execve(WRAPPED_PROGRAM, argv, NULL);

    return 1;
}

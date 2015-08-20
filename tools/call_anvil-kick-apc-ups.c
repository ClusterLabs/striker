/* Compile by entering 'gcc -o call_anvil-kick-apc-ups call_anvil-kick-apc-ups.c' */
#define REAL_PATH "/sbin/striker/anvil-kick-apc-ups"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


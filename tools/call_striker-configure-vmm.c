/* Compile by entering 'gcc -o call_striker-configure-vmm call_striker-configure-vmm.c' */
#define REAL_PATH "/sbin/striker/striker-configure-vmm"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


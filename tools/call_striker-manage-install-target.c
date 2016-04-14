/* Compile by entering 'gcc -o call_striker-manage-install-target call_striker-manage-install-target.c' */
#define REAL_PATH "/sbin/striker/striker-manage-install-target"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


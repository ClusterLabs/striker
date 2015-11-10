/* Compile by entering 'gcc -o call_striker-merge-dashboards call_striker-merge-dashboards.c' */
#define REAL_PATH "/sbin/striker/striker-merge-dashboards"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


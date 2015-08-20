/* Compile by entering 'gcc -o touch_striker.log touch_striker.log.c' */
#define REAL_PATH "/sbin/dashboard/touch_striker.log.sh"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


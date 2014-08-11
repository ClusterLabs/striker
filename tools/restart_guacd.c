/* Compile by entering 'gcc -o restart_guacd restart_guacd.c' */
#define REAL_PATH "/etc/init.d/guacd"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


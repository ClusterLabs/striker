/* Compile by entering 'gcc -o check_dvd check_dvd.c' */
#define REAL_PATH "/usr/bin/cd-info"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


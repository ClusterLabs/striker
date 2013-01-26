/* Compile by entering 'gcc -o do_dd do_dd.c' */
#define REAL_PATH "/bin/dd"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


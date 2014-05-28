/* Compile by entering 'gcc -o call_gather-system-info call_gather-system-info.c' */
#define REAL_PATH "/var/www/tools/gather-system-info"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


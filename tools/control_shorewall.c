/* Compile by entering 'gcc -o control_shorewall control_shorewall.c' */
#define REAL_PATH "/etc/init.d/shorewall"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


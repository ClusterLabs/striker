/* Compile by entering 'gcc -o control_dhcpd control_dhcpd.c' */
#define REAL_PATH "/etc/init.d/dhcpd"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


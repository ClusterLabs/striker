/* Compile by entering 'gcc -o control_iptables control_iptables.c' */
#define REAL_PATH "/etc/init.d/iptables"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


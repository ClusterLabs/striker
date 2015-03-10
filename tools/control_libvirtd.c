/* Compile by entering 'gcc -o control_libvirtd control_libvirtd.c' */
#define REAL_PATH "/etc/init.d/libvirtd"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


/* Compile by entering 'gcc -o restart_tomcat6 restart_tomcat6.c' */
#define REAL_PATH "/etc/init.d/tomcat6"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


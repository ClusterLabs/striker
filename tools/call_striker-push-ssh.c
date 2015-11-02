/* Compile by entering 'gcc -o call_striker-push-ssh call_striker-push-ssh.c' */
#define REAL_PATH "/sbin/striker/striker-push-ssh"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


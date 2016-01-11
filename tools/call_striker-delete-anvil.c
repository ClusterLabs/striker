/* Compile by entering 'gcc -o call_striker-delete-anvil call_striker-delete-anvil.c' */
#define REAL_PATH "/sbin/striker/striker-delete-anvil"
main(ac, av)
char **av;
{
	setuid(0);
	setgid(0);
	execv(REAL_PATH, av);
}


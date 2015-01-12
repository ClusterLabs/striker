/* program to run storcli64 as root */

#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>

#define STORCLI "/sbin/storcli64"
#define END     ((char *) 0)

void usage( char * argv) {

  char * fmt = "\n"
"USAGE: %s [controller 0-9] [drives 0-9] \n"
"\n"
"    Run the program with no options to get a list of all controllers    \n"
"    controller N, where N is 0 .. 9, to extract info about controller N \n"
"    drive N, where N is 0 ... 9, to extract drive data for controller N \n"
"    real uid: %d   effective uid: %d\n"
"\n";


  fprintf( stderr, fmt, argv, getuid(), geteuid() );
}

int main ( int argc, char * argv[] ) {

  char * env[] = { "HOME=/root", "PATH=/sbin", (char *)0 };
  int ret;

  setuid( geteuid() );
  /*
   * Get summary info, including number of controllers.
   */
  if ( argc == 1 ) {
      ret = execle( STORCLI, "storcli", "show", "all", END, env );
  }
  /*
   * Get info for controller N.
   */
  else if ( strcmp(argv[1], "controller" ) == 0 
	    && argc == 3 
	    && isdigit( argv[2][0] )
	    ) {
    int N = atoi( argv[2] );
    char buf[10];

    if ( N > 10 ) {
      fprintf( stderr,
	      "storcli wrapper only handles max 9 controllers, you gave '%d'\n",
	      N );
    }
    sprintf( buf, "/c%d", N);
    ret = execle( STORCLI, "storcli", buf, "show", "all", END, env );
  }
  /*
   * Get info for drives connected  to controller N.
   */
  else if ( strcmp(argv[1], "drives" ) == 0 
	    && argc == 3 
	    && isdigit( argv[2][0] )
	    ) {
    int N = atoi( argv[2] );
    char buf[10];

    if ( N > 10 ) {
      fprintf( stderr,
	      "storcli wrapper only handles max 9 controllers, you gave '%d'\n",
	      N );
    }
    sprintf( buf, "/c%d", N);
    ret = execle( STORCLI, "storcli", buf, "/eall", "/sall", "show", "all",
		  END, env );
  }
  else {
    usage(argv[0]);
  }

  return ( ret );
}
/* end of file */

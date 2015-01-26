/* program to run the shutdown tool as root */

#include <stdio.h>
#include <unistd.h>

int main ( ) {

  char * env[] = { "HOME=/root", "PATH=/sbin", (char *)0 };
 
  setuid( geteuid() );

  printf( "Path is %s\n", env[1] );

  int ret = execle( "/var/www/tools/safe-anvil-shutdown", "safe-anvil-shutdown",
                    (char *) 0, env );

  return ( ret );
}
/* end of file */

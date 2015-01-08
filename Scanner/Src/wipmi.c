/* program to run ipmitool as root */

#include <stdio.h>
#include <unistd.h>

int main ( ) {

  char * env[] = { "HOME=/root", "PATH=/usr/bin", (char *)0 };

  int ret = execle( "/usr/bin/ipmitool", "ipmitool", "sdr", "type", "temp", (char *) 0, env );

  return ( ret );
}
/* end of file */

#import <mui/MCCPowerTerm.h>
#import <mui/PowerTerm_mcc.h>

@interface Terminal : MCCPowerTerm

-(VOID) write: (OBData *)data encoding: (ULONG)characterEncoding;

@end

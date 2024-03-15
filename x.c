#include <linux/ioctl.h>
#include <linux/if.h>
#include <linux/if_tun.h>
int main() {
    printf("0x%08x\n", TUNSETIFF);
    printf("0x%08x\n", IFF_TUN);
    printf("0x%08x\n", IFF_TAP);
    printf("0x%08x\n", IFF_NO_PI);
    printf("0x%08x\n", IFNAMSIZ);
    return 0;
}

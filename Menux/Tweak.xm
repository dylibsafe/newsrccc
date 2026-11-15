#import <UIKit/UIKit.h>
#import <JRMemory/MemScan.h>
#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <mach/mach_traps.h>

// Global variables to store the state of CheckBoxes
bool LockStatus = false;
bool SpeedPlayer = false;

/*
This Function checks if the Application has ASLR enabled.
*/
bool hasASLR() {
    const struct mach_header *mach;
    mach = _dyld_get_image_header(0);

    if (mach->flags & MH_PIE) {
        return TRUE;
    } else {
        return FALSE;
    }
}

/*
This Function gets the vmaddr slide of the Image at Index 0.
*/
long long get_slide() {
    return _dyld_get_image_vmaddr_slide(0);
}

/*
This Function calculates the Address if ASLR is enabled or returns the normal offset.
*/
long long calculateAddress(long long offset) {
    if (hasASLR()) {
        long long slide = get_slide();
        return (slide + offset);
    } else {
        return offset;
    }
}

/*
HATA DÜZELTİLDİ: Verinin 4 byte mi yoksa 2 byte mi olduğunu daha güvenli kontrol eder.
*/
bool getType(unsigned int data) {
    // Eğer veri 0xFFFF'den büyükse 32-bit (4 byte), küçükse 16-bit (2 byte) kabul ediyoruz.
    if (data > 0xFFFF) {
        return true;  // 32-bit
    } else {
        return false; // 16-bit
    }
}

/*
HATA DÜZELTİLDİ: ARM64 hizalama hatalarını (EXC_ARM_DA_ALIGN) önlemek için 
geçici değişkenler kullanıldı ve boyutlar (writeSize) netleştirildi.
*/
bool vm_writeData(long long offset, unsigned int data) {
    kern_return_t err;
    mach_port_t port = mach_task_self();
    long long address = calculateAddress(offset);

    if (address == 0) return FALSE;

    // Yazılacak verinin boyutunu belirle
    vm_size_t writeSize = 4; // Varsayılan 4 byte
    if (!getType(data)) {
        writeSize = 2; // Eğer 16-bit ise 2 byte
    }

    // Bellek korumasını değiştir (Yazma izni ver)
    err = vm_protect(port, (vm_address_t)address, writeSize, NO, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (err != KERN_SUCCESS) {
        NSLog(@"[M7MD] vm_protect failed: %d", err);
        return FALSE;
    }

    // Veriyi yaz (Hizalama hatasını önlemek için geçici değişkenler kullanıldı)
    if (writeSize == 4) {
        uint32_t swapped = CFSwapInt32(data);
        err = vm_write(port, (vm_address_t)address, (vm_offset_t)&swapped, writeSize);
    } else {
        uint16_t swapped = CFSwapInt16((uint16_t)data);
        err = vm_write(port, (vm_address_t)address, (vm_offset_t)&swapped, writeSize);
    }
    
    if (err != KERN_SUCCESS) {
        NSLog(@"[M7MD] vm_write failed: %d", err);
        return FALSE;
    }
    
    // Bellek korumasını eski haline getir (Sadece okunabilir ve çalıştırılabilir)
    err = vm_protect(port, (vm_address_t)address, writeSize, NO, VM_PROT_READ | VM_PROT_EXECUTE);

    return TRUE;
}

/*
Function to apply the LockStatus patch based on the CheckBox state.
*/
void setLockStatus(bool state) {
    LockStatus = state;
    if (LockStatus) {
        bool success = vm_writeData(0x102CA170C, 0x1F2003D5);
        if (success) {
            NSLog(@"[M7MD] LockStatus enabled successfully");
        } else {
            NSLog(@"[M7MD] Failed to enable LockStatus");
        }
    } else {
        NSLog(@"[M7MD] LockStatus disabled");
    }
}

/*
Function to apply the SpeedPlayer patch based on the CheckBox state.
*/
void setSpeedPlayer(bool state) {
    SpeedPlayer = state;
    if (SpeedPlayer) {
        bool success = vm_writeData(0x102C10D84, 0x0810281E);
        if (success) {
            NSLog(@"[M7MD] SpeedPlayer enabled successfully");
        } else {
            NSLog(@"[M7MD] Failed to enable SpeedPlayer");
        }
    } else {
        NSLog(@"[M7MD] SpeedPlayer disabled");
    }
}

// UI implementation
@interface TweakViewController : UIViewController
@property (nonatomic, strong) UISwitch *lockStatusSwitch;
@property (nonatomic, strong) UISwitch *speedPlayerSwitch;
@end

@implementation TweakViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Create LockStatus Switch
    self.lockStatusSwitch = [[UISwitch alloc] init];
    [self.lockStatusSwitch addTarget:self action:@selector(lockStatusChanged:) forControlEvents:UIControlEventValueChanged];
    
    // Create SpeedPlayer Switch
    self.speedPlayerSwitch = [[UISwitch alloc] init];
    [self.speedPlayerSwitch addTarget:self action:@selector(speedPlayerChanged:) forControlEvents:UIControlEventValueChanged];
    
    // Add switches to view
    [self.view addSubview:self.lockStatusSwitch];
    [self.view addSubview:self.speedPlayerSwitch];
}

- (void)lockStatusChanged:(UISwitch *)sender {
    setLockStatus(sender.isOn);
}

- (void)speedPlayerChanged:(UISwitch *)sender {
    setSpeedPlayer(sender.isOn);
}

@end

#import "MemScan.h"
#include <mach/mach.h>
#include <vector>
#include <algorithm>

// Temel bellek okuma fonksiyonu
void *JRMemoryEngine::JRReadMemory(unsigned long long address, size_t len) {
    if (address == 0 || len == 0) return NULL;
    
    void *buffer = malloc(len);
    if (!buffer) return NULL;
    
    mach_vm_size_t outsize = 0;
    kern_return_t kret = mach_vm_read_overwrite(task, (mach_vm_address_t)address, (mach_vm_size_t)len, (mach_vm_address_t)buffer, &outsize);
    
    if (kret != KERN_SUCCESS) {
        free(buffer);
        return NULL;
    }
    return buffer;
}

// Temel bellek yazma fonksiyonu
void JRMemoryEngine::JRWriteMemory(unsigned long long address, void *target, size_t len) {
    if (address == 0 || target == NULL || len == 0) return;
    mach_vm_write(task, (mach_vm_address_t)address, (vm_offset_t)target, (mach_msg_type_number_t)len);
}

// Bellek Tarama Fonksiyonu (Basitleştirilmiş AOB Scan)
void JRMemoryEngine::JRScanMemory(AddrRange range, void *target, size_t len) {
    if (range.start == 0 || range.end == 0 || target == NULL || len == 0) return;
    
    uint64_t current = range.start;
    size_t chunkSize = 1024 * 1024; // 1MB'lık parçalar halinde oku
    
    while (current < range.end) {
        mach_vm_size_t outsize = 0;
        void *buffer = malloc(chunkSize);
        
        kern_return_t kret = mach_vm_read_overwrite(task, current, chunkSize, (mach_vm_address_t)buffer, &outsize);
        
        if (kret == KERN_SUCCESS && outsize > 0) {
            // Basit bir arama (memcmp)
            for (size_t i = 0; i < outsize - len; i++) {
                if (memcmp((char*)buffer + i, target, len) == 0) {
                    // Bulundu! result yapısına ekle
                    result_region *region = new result_region();
                    region->region_base = current + i;
                    region->slide.push_back(0); // Basit tutuyoruz
                    
                    this->result->resultBuffer.push_back(region);
                    this->result->count++;
                }
            }
        }
        free(buffer);
        current += chunkSize;
    }
}

// Yakınlık araması (Şimdilik boş bırakıyoruz, gerekirse doldurulur)
void JRMemoryEngine::JRNearBySearch(int range, void *target, size_t len) {
    // İhtiyaç halinde JRScanMemory benzeri bir mantıkla yazılabilir
}

// Sonuçları döndürme
vector<void*> JRMemoryEngine::getAllResults() {
    vector<void*> results;
    for (int i = 0; i < result->count; i++) {
        results.push_back((void*)result->resultBuffer[i]->region_base);
    }
    return results;
}

vector<void*> JRMemoryEngine::getResults(int count) {
    vector<void*> results;
    for (int i = 0; i < count && i < result->count; i++) {
        results.push_back((void*)result->resultBuffer[i]->region_base);
    }
    return results;
}

// Bellek ayırma ve temizleme
Result* ResultAllocate(void) {
    Result *newResult = new Result();
    newResult->count = 0;
    return newResult;
}

void ResultDeallocate(Result *result) {
    if (!result) return;
    for (int i = 0; i < result->resultBuffer.size(); i++) {
        delete result->resultBuffer[i];
    }
    result->resultBuffer.clear();
    delete result;
}

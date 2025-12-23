pub const Constants = struct {
    kByteCountMask: u32 = 0x40000000,
    kClassMask: u32 = 0x80000000,
    kMapOffset: u32 = 2,
    kFileHeaderSize: u32 = 100,
    kNewClassFlag: u32 = 0xFFFFFFFF,
};

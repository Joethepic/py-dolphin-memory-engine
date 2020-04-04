from typing import List

from libc.stdint cimport uint32_t, uint64_t
from libcpp cimport bool as c_bool
from libcpp.string cimport string


cdef extern from "Common/MemoryCommon.h" namespace "Common::MemType":
    cdef enum MemType:
        type_word


cdef extern from "Common/MemoryCommon.h" namespace "Common::MemBase":
    cdef enum MemBase:
        base_decimal


cdef extern from "Common/MemoryCommon.h" namespace "Common::MemOperationReturnCode":
    cdef enum MemOperationReturnCode:
        invalidInput
        operationFailed
        inputTooLong
        invalidPointer
        OK

cdef extern from "Common/CommonUtils.h" namespace "Common":
    uint32_t dolphinAddrToOffset(uint32_t)
    uint32_t offsetToDolphinAddr(uint32_t)


cdef extern from "DolphinProcess/DolphinAccessor.h" namespace "DolphinComm::DolphinStatus":
    cdef enum DolphinStatus:
        hooked
        notRunning
        noEmu
        unHooked


cdef extern from "DolphinProcess/DolphinAccessor.h" namespace "DolphinComm":
    cdef cppclass DolphinAccessor:
        @staticmethod
        void init()

        @staticmethod
        void free()

        @staticmethod
        void hook()

        @staticmethod
        void unHook()

        @staticmethod
        c_bool readFromRAM(uint32_t, char*, const size_t, c_bool)
        
        @staticmethod
        c_bool writeToRAM(uint32_t, const char*, const size_t, c_bool)

        @staticmethod
        int getPID()
        
        @staticmethod
        DolphinStatus getStatus()

        @staticmethod
        c_bool isValidConsoleAddress(uint32_t)


cdef extern from "MemoryWatch/MemWatchEntry.h":
    cdef cppclass MemWatchEntry:
        MemWatchEntry()
        MemWatchEntry(string, uint32_t, MemType, MemBase, c_bool, size_t, c_bool)

        char* getMemory()

        void addOffset(int)
        MemOperationReturnCode readMemoryFromRAM()
        MemOperationReturnCode writeMemoryFromString(string)


cdef buffer_to_value(char* buffer):
    cdef uint32_t* value = <uint32_t*> buffer
    return value[0]


cdef value_to_buffer(char* buffer, uint32_t value):
    cdef uint32_t* b = <uint32_t*> buffer
    b[0] = value


cdef class MemWatch:
    cdef MemWatchEntry c_entry

    def __cinit__(self, label: str, console_address: int, is_pointer: bool):
        self.c_entry = MemWatchEntry(label.encode("utf-8"), console_address, MemType.type_word, MemBase.base_decimal, False, 1, is_pointer)

    def add_offset(self, offset: int):
        self.c_entry.addOffset(offset)

    def get_value(self):
        return buffer_to_value(self.c_entry.getMemory())
        
    def read_memory_from_ram(self):
        return self.c_entry.readMemoryFromRAM() == MemOperationReturnCode.OK

    def write_memory_from_string(self, value: str):
        return self.c_entry.writeMemoryFromString(value.encode("utf-8")) == MemOperationReturnCode.OK


def hook():
    return DolphinAccessor.hook()


def un_hook():
    return DolphinAccessor.unHook()


def is_hooked() -> bool:
    if DolphinAccessor.getStatus() == DolphinStatus.hooked:
        return True
    else:
        return False


def follow_pointers(console_address: int, pointer_offsets: List[int]) -> int:
    real_console_address = console_address

    cdef char memory_buffer[4]
    for offset in pointer_offsets:
        if DolphinAccessor.readFromRAM(dolphinAddrToOffset(real_console_address), memory_buffer, 4, True):
            real_console_address = buffer_to_value(memory_buffer)
            if DolphinAccessor.isValidConsoleAddress(real_console_address):
                real_console_address += offset
            else:
                raise RuntimeError(f"Address {real_console_address} is not valid")
        else:
            raise RuntimeError(f"Could not read memory at {real_console_address}")

    return real_console_address


def read_word(console_address: int) -> int:
    cdef char memory_buffer[4]
    if DolphinAccessor.readFromRAM(dolphinAddrToOffset(console_address), memory_buffer, 4, True):
        return buffer_to_value(memory_buffer)
    else:
        raise RuntimeError(f"Could not read memory at {console_address}")


def write_word(console_address: int, value: int):
    cdef char memory_buffer[4]
    value_to_buffer(memory_buffer, value)
    if not DolphinAccessor.writeToRAM(dolphinAddrToOffset(console_address), memory_buffer, 4, True):
        raise RuntimeError(f"Could not write memory at {console_address}")
#include "cellarray.inc"

enum Queue {
    Invalid_Queue = 0
};

stock Queue: QueueCreate(const cellsize = 1) {
    return Queue: ArrayCreate(cellsize);
}

stock QueueDestroy(&Queue: which) {
    return ArrayDestroy(Array: which);
}

stock QueueClear(const &Queue: which) {
    ArrayClear(Array: which);
}

stock Queue: QueueClone(const &Queue: which) {
    return ArrayClone(Array: which);
}

stock QueuePushCell(const &Queue: which, const any: value) {
    return ArrayPushCell(Array: which, any: value);
}

stock QueuePushString(const &Queue: which, const value[]) {
    return ArrayPushString(Array: which, value);
}

stock QueuePushArray(const &Queue: which, const any: value[], const size = -1) {
    return ArrayPushArray(Array: which, value, size);
}

stock any: QueuePopCell(const &Queue: which) {
    new any: value = ArrayGetCell(Array: which, 0);
    ArrayDeleteItem(Array: which, 0);
    return value;
}

stock QueuePopString(const &Queue: which, buffer[], const maxlength) {
    new charCount = ArrayGetString(Array: which, 0, buffer, maxlength);
    ArrayDeleteItem(Array: which, 0);
    return charCount;
}

stock QueuePopArray(const &Queue: which, buffer[], const size) {
    new cellCount = ArrayGetArray(Array: which, 0, buffer, size);
    ArrayDeleteItem(Array: which, 0);
    return cellCount;
}

stock any: QueueFrontCell(const &Queue: which) {
    new any: value = ArrayGetCell(Array: which, 0);
    return value;
}

stock QueueFrontString(const &Queue: which, buffer[], const maxlength) {
    new charCount = ArrayGetString(Array: which, 0, buffer, maxlength);
    return charCount;
}

stock QueueFrontArray(const &Queue: which, buffer[], const size) {
    new cellCount = ArrayGetArray(Array: which, 0, buffer, size);
    return cellCount;
}

stock any: QueueRearCell(const &Queue: which) {
    new any: value = ArrayGetCell(Array: which, QueueSize(which) - 1);
    return value;
}

stock QueueRearString(const &Queue: which, buffer[], const maxlength) {
    new charCount = ArrayGetString(Array: which, QueueSize(which) - 1, buffer, maxlength);
    return charCount;
}

stock QueueRearArray(const &Queue: which, buffer[], const size) {
    new cellCount = ArrayGetArray(Array: which, QueueSize(which) - 1, buffer, size);
    return cellCount;
}

stock QueueSize(const &Queue: which) {
    return ArraySize(Array: which);
}

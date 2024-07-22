const std = @import("std");
const mem = std.mem;

const StructField = std.builtin.Type.StructField;

fn structToMemoryLayout(comptime Type: type) type {
    var info = @typeInfo(Type);
    if (info == .Struct) {
        const field_count = info.Struct.fields.len;
        var new_fields = [_]StructField{undefined} ** field_count;
        mem.copyForwards(StructField, &new_fields, info.Struct.fields);
        for (info.Struct.fields, 0..) |_, i| {
            new_fields[i].type = usize;
            // TODO is explicity setting alignment necessary
            // new_fields[i].alignment = @alignOf(usize);
        }
        info.Struct.fields = &new_fields;
        return @Type(info);
    }

    // TODO better errors
    unreachable;
}

pub fn buildMemoryLayout(comptime Type: type) structToMemoryLayout(Type) {
    const info = @typeInfo(Type);
    if (info == .Struct) {
        var ret: structToMemoryLayout(Type) = undefined;
        var mem_at = 0;
        for (info.Struct.fields) |field| {
            @field(ret, field.name) = mem_at;
            mem_at += @sizeOf(field.type);
        }
        return ret;
    }

    // TODO better errors
    unreachable;
}

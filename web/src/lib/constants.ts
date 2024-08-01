export const MAX_VM_MEMORY_SIZE = 32 * 1024;

export const cells = (count: number) => count * 2;
export const cell = cells(1);

const memory_layout_spec = {
  program_counter: cell,
  return_stack_top: cell,
  return_stack: cells(32),
  return_stack_end: 0,
  data_stack_top: cell,
  data_stack: cells(32),
  data_stack_end: 0,
  here: cell,
  latest: cell,
  state: cell,
  base: cell,
  active_device: cell,
  input_buffer_at: cell,
  input_buffer_len: cell,
  input_buffer: 128,
  devices: 256,
  dictionary_start: 0,
};

type MemoryLocations = typeof memory_layout_spec;

const buildMemoryLocations = () => {
  return Object.entries(memory_layout_spec).reduce(
    ({ acc, count }, [key, value]) => {
      acc[key as keyof MemoryLocations] = count;
      return { acc, count: count + value };
    },
    { acc: {} as MemoryLocations, count: 0 }
  ).acc;
};

export const MEMORY_LAYOUT = buildMemoryLocations();

export const showMemoryLayout = (object: { [key: string]: number }) => {
  Object.entries(object).forEach((x) => console.log(x));
};

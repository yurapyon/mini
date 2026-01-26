export const TitleBar = () => {
  return (
    <div class="w-full flex flex-row bg-[#181818] items-center gap-8">
      <div class="text-nowrap">: mini ;</div>
      <div class="grow min-w-0" />
      <a
        class="shrink-0 bg-[#505050] hover:bg-[#101010] px-[1ch]"
        href="https://github.com/yurapyon/mini"
        target="_blank"
      >
        mini git repo
      </a>
    </div>
  );
};

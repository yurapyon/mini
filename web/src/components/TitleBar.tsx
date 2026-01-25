export const TitleBar = () => {
  return <div class="w-full flex flex-row bg-[#181818] items-center gap-8">
    <div class="text-nowrap">: mini ;</div>
    <div class="text-xs text-[#a0a0a0] text-ellipsis overflow-clip text-nowrap min-w-0 grow">
      Click on the terminal to activate it.
      Enter commands and press enter!
      (you can also click on the commands below the editor)
    </div>
    <a class="shrink-0 hover:bg-[#404040]" href="https://github.com/yurapyon/mini" target="_blank">Github</a>
  </div>;
};

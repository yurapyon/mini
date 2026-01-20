external allocate
external allocate-page
external free
external reallocate
external dynsize
external dyn!
external dyn+!
external dyn@
external dync!
external dyn+c!
external dync@

external >dyn    \ ( s d h l -- )     copies from forth memory to dynamic memory
external dyn>    \ ( s h d l -- )     copies from dynamic memory to forth memory
external dynmove \ ( s sh d dh l -- ) copies between dynamic memory


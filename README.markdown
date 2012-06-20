MOScrollView
===============


Introduction
------------

Subclass of UIScrollView that, in contrast to UIScrollView, uses a custom
timing function to animate setContentOffset.


Features
--------

Provides methods

    - (void)setContentOffset:(CGPoint)contentOffset 
          withTimingFunction:(CAMediaTimingFunction *)timingFunction

and 

    - (void)setContentOffset:(CGPoint)contentOffset 
          withTimingFunction:(CAMediaTimingFunction *)timingFunction
                    duration:(CFTimeInterval)duration


Usage
-----

Simply import `MOScrollView.h` and `MOScrollView.m` into your project. As the
class uses automatic refernce counting either your project has to use automatic
reference counting as well or you have to enable automatic reference counting for
`MOScrollView.m` by adding `-fobjc-arc` as compiler flag in Build Phases options.


Requirements
------------

XCode 4.2 or later and iOS 4 or later as the module uses automatic reference counting. 


License
-------

`MOScrollView` is released under Modified BSD License.

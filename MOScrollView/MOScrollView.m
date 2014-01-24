//
//  MOScrollView.m
//  MOScrollView
//
//  Created by Jan Christiansen on 6/20/12.
//  Copyright (c) 2012, Monoid - Development and Consulting - Jan Christiansen
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above
//  copyright notice, this list of conditions and the following
//  disclaimer in the documentation and/or other materials provided
//  with the distribution.
//
//  * Neither the name of Monoid - Development and Consulting - 
//  Jan Christiansen nor the names of other
//  contributors may be used to endorse or promote products derived
//  from this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
//  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
//  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
//  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import <QuartzCore/QuartzCore.h>
#import "MOScrollView.h"

const static CFTimeInterval kDefaultSetContentOffsetDuration = 0.25;

/// Constants used for Newton approximation of cubic function root.
const static double kApproximationTolerance = 0.00000001;
const static int kMaximumSteps = 10;

@interface MOScrollView ()

/// Display link used to trigger event to scroll the view.
@property(nonatomic) CADisplayLink *displayLink;

/// Timing function of an scroll animation.
@property(nonatomic) CAMediaTimingFunction *timingFunction;

/// Duration of an scroll animation.
@property(nonatomic) CFTimeInterval duration;

/// States whether the animation has started.
@property(nonatomic) BOOL animationStarted;

/// Time at the begining of an animation.
@property(nonatomic) CFTimeInterval beginTime;

/// The content offset at the begining of an animation.
@property(nonatomic) CGPoint beginContentOffset;

/// The delta between the contentOffset at the start of the animation and
/// the contentOffset at the end of the animation.
@property(nonatomic) CGPoint deltaContentOffset;

@end

@implementation MOScrollView

#pragma mark - Set ContentOffset with Custom Animation

- (void)setContentOffset:(CGPoint)contentOffset
      withTimingFunction:(CAMediaTimingFunction *)timingFunction {
    [self setContentOffset:contentOffset
        withTimingFunction:timingFunction
                  duration:kDefaultSetContentOffsetDuration];
}

- (void)setContentOffset:(CGPoint)contentOffset
      withTimingFunction:(CAMediaTimingFunction *)timingFunction
                duration:(CFTimeInterval)duration {
    self.duration = duration;
    self.timingFunction = timingFunction;

    self.deltaContentOffset = CGPointMinus(contentOffset, self.contentOffset);

    if (!self.displayLink) {
        self.displayLink = [CADisplayLink
                            displayLinkWithTarget:self
                            selector:@selector(updateContentOffset:)];
        self.displayLink.frameInterval = 1;
        [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop]
                               forMode:NSDefaultRunLoopMode];
    } else {
        self.displayLink.paused = NO;
    }
}

- (void)updateContentOffset:(CADisplayLink *)displayLink {
    if (self.beginTime == 0.0) {
        self.beginTime = self.displayLink.timestamp;
        self.beginContentOffset = self.contentOffset;
    } else {
        CFTimeInterval deltaTime = displayLink.timestamp - self.beginTime;

        // Ratio of duration that went by
        CGFloat progress = (CGFloat)(deltaTime / self.duration);
        if (progress < 1.0) {
            // Ratio adjusted by timing function
            CGFloat adjustedProgress = (CGFloat)timingFunctionValue(self.timingFunction, progress);
            if (1 - adjustedProgress < 0.001) {
                [self stopAnimation];
            } else {
                [self updateProgress:adjustedProgress];
            }
        } else {
            [self stopAnimation];
        }
    }
}

- (void)updateProgress:(CGFloat)progress {
    CGPoint currentDeltaContentOffset = CGPointScalarMult(progress, self.deltaContentOffset);
    self.contentOffset = CGPointAdd(self.beginContentOffset, currentDeltaContentOffset);
}

- (void)stopAnimation {
    self.displayLink.paused = YES;
    self.beginTime = 0.0;

    self.contentOffset = CGPointAdd(self.beginContentOffset, self.deltaContentOffset);

    if (self.delegate
        && [self.delegate respondsToSelector:@selector(scrollViewDidEndScrollingAnimation:)]) {
        // inform delegate about end of animation
        [self.delegate scrollViewDidEndScrollingAnimation:self];
    }
}

CGPoint CGPointScalarMult(CGFloat s, CGPoint p) {
    return CGPointMake(s * p.x, s * p.y);
}

CGPoint CGPointAdd(CGPoint p, CGPoint q) {
    return CGPointMake(p.x + q.x, p.y + q.y);
}

CGPoint CGPointMinus(CGPoint p, CGPoint q) {
    return CGPointMake(p.x - q.x, p.y - q.y);
}

double cubicFunctionValue(double a, double b, double c, double d, double x) {
    return (a*x*x*x)+(b*x*x)+(c*x)+d;
}

double cubicDerivativeValue(double a, double b, double c, double __unused d, double x) {
    /// Derivation of the cubic (a*x*x*x)+(b*x*x)+(c*x)+d
    return (3*a*x*x)+(2*b*x)+c;
}

double rootOfCubic(double a, double b, double c, double d, double startPoint) {
    // We use 0 as start point as the root will be in the interval [0,1]
    double x = startPoint;
    double lastX = 1;

    // Approximate a root by using the Newton-Raphson method
    int y = 0;
    while (y <= kMaximumSteps && fabs(lastX - x) > kApproximationTolerance) {
        lastX = x;
        x = x - (cubicFunctionValue(a, b, c, d, x) / cubicDerivativeValue(a, b, c, d, x));
        y++;
    }

    return x;
}

double timingFunctionValue(CAMediaTimingFunction *function, double x) {
    float a[2];
    float b[2];
    float c[2];
    float d[2];

    [function getControlPointAtIndex:0 values:a];
    [function getControlPointAtIndex:1 values:b];
    [function getControlPointAtIndex:2 values:c];
    [function getControlPointAtIndex:3 values:d];

    // Look for t value that corresponds to provided x
    double t = rootOfCubic(-a[0]+3*b[0]-3*c[0]+d[0], 3*a[0]-6*b[0]+3*c[0], -3*a[0]+3*b[0], a[0]-x, x);

    // Return corresponding y value
    double y = cubicFunctionValue(-a[1]+3*b[1]-3*c[1]+d[1], 3*a[1]-6*b[1]+3*c[1], -3*a[1]+3*b[1], a[1], t);

    return y;
}

@end


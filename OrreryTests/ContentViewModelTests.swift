//
//  ContentViewModelTests.swift
//  OrreryTests
//

import Testing
@testable import Orrery

@MainActor
struct ContentViewModelTests {
    @Test func effectiveAnimation_usesReducedAnimationOnlyWhenReduceMotionIsOn() {
        let viewModel = ContentViewModel()
        #expect(viewModel.effectiveAnimation(reduceMotion: false) == viewModel.animation)
        #expect(viewModel.effectiveAnimation(reduceMotion: true) == viewModel.reducedAnimation)
        #expect(viewModel.animation != viewModel.reducedAnimation)
    }
}

return {
	tests = {
		test_module_requires = {
			module = "./test_module_requires",
			cases = {
				replicatedStorageAndRelativeRequires = {},
				playerScriptsClientRequires = {},
				starterPlayerScriptsClientRequires = {},
				aliasRequires = {},
			},
		},
		test_sandboxing = {
			module = "./test_sandboxing",
			cases = {
				sandboxedGlobalState1 = {},
				sandboxedGlobalState2 = {},
			},
		},
		test_runner_core = {
			module = "./test_runner_core",
			cases = {
				mountsServicesIntoGlobals = {},
				instanceRequireResolvesNestedModuleScripts = {},
				moduleStateStartsFreshPerCase1 = {},
				moduleStateStartsFreshPerCase2 = {},
				serviceTreeStartsFreshPerCase1 = {},
				serviceTreeStartsFreshPerCase2 = {},
				caseArgumentsArePassedThrough = { 7, 3, 4 },
				singleLiteralCaseArgumentIsPassedThrough = "hello",
				lazyTableCaseArgumentsArePassedThrough = function()
					return { 9, 4, 5 }
				end,
				lazySingleCaseArgumentIsPassedThrough = function()
					return "lazy"
				end,
			},
		},
		test_fake_classes = {
			module = "./test_fake_classes",
			cases = {
				vector2DefaultsAndConstants = {},
				vector2ArithmeticAndHelpers = {},
				vector3ArithmeticAndCrossProduct = {},
				vector3HelpersAndConstants = {},
				udimArithmetic = {},
				udim2ConstructorsAndLerp = {},
				color3RgbHexAndClamp = {},
				color3HsvRoundTripAndLerp = {},
				cframeConstructionAndOperators = {},
				cframeOrientationAndLookAt = {},
				brickColorConstructorsAndEquality = {},
				brickColorPaletteClosestAndRandom = {},
				randomDeterminismCloneAndRanges = {},
				randomUnitVectorAndShuffle = {},
				instanceHierarchyAndLookup = {},
				instanceRenameWaitAndDestroy = {},
			},
		},
		test_fake_runtime = {
			module = "./test_fake_runtime",
			cases = {
				servicesAreStableAndConfigurable = {},
				createEnvironmentIsAvailableAsASandboxGlobal = {},
				instanceHierarchyAttributesAndSignals = {},
				signalDisconnectPreventsFurtherFires = {},
				signalDisconnectAllAndDisconnectDuringFire = {},
				collectionServiceTracksTagsAndCleanup = {},
				collectionServiceSignalsDataModelMembershipChanges = {},
				remoteEventRoutesAcrossServerAndClients = {},
				remoteFunctionSupportsInvokeServerAndClient = {},
				remoteFailuresProduceActionableErrors = {},
				pairedClientsShareReplicatedTreeAndLocalPlayerContext = {},
				playersLifecycleAndCharacterReplacementAreDeterministic = {},
				playersLookupAndLocalPlayerTransitions = {},
				schedulerSupportsSpawnDeferDelayWaitAndHeartbeat = {},
				schedulerCancellationTimeoutRunAllAndErrors = {},
				memoryStoreTeleportDiagnosticsAndResetWork = {},
				memoryStoreAdditionalMapAndQueueBranches = {},
				environmentAvailabilityOverridesAndErrorsAreActionable = {},
				configureAndResetRefreshLiveServicesAndObjects = {},
				instanceEventSemanticsAndChildClearing = {},
				waitForChildImmediateTimeoutAndNoSchedulerErrors = {},
				environmentInstallUninstall = {},
				multiEnvironmentParenting = {},
				getEnvironmentReturnsCurrentEnvironment = {},
			},
		},
	},
	mounts = {
		ReplicatedStorage = "test/fixture-main/src/shared",
		ServerScriptService = "./src/server",
		PlayerScripts = "./src/client",
	},
}

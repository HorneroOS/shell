pragma Singleton

import qs.utils
import Hornero
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property alias appearance: adapter.appearance
    property alias general: adapter.general
    property alias background: adapter.background
    property alias bar: adapter.bar
    property alias border: adapter.border
    property alias dashboard: adapter.dashboard
    property alias controlCenter: adapter.controlCenter
    property alias launcher: adapter.launcher
    property alias notifs: adapter.notifs
    property alias osd: adapter.osd
    property alias session: adapter.session
    property alias winfo: adapter.winfo
    property alias lock: adapter.lock
    property alias utilities: adapter.utilities
    property alias sounds: adapter.sounds
    property alias sidebar: adapter.sidebar
    property alias services: adapter.services
    property alias paths: adapter.paths
    property alias plugins: adapter.plugins
    property alias experience: adapter.experience
    property alias layouts: adapter.layouts

    property bool editSessionActive: false
    property bool hasPendingChanges: false

    function beginEditSession(): void {
        editSessionActive = true;
    }

    function endEditSession(): void {
        editSessionActive = false;
    }

    function writeNow(): void {
        timer.restart();
        try {
            let config = {};
            try {
                config = JSON.parse(fileView.text());
            } catch (e) {
                config = {};
            }

            config = serializeConfig();
            fileView.setText(JSON.stringify(config, null, 2));
            recentlySaved = true;
            recentSaveCooldown.restart();
            hasPendingChanges = false;
        } catch (e) {
            Toaster.toast(qsTr("Failed to serialize config"), e.message, "settings-exclamation", Toast.Error);
        }
    }

    function revertChanges(): void {
        hasPendingChanges = false;
        recentlySaved = false;
        fileView.reload();
    }

    // Public save function - call this to persist config changes
    function save(): void {
        if (editSessionActive) {
            hasPendingChanges = true;
            return;
        }
        saveTimer.restart();
        recentlySaved = true;
        recentSaveCooldown.restart();
        hasPendingChanges = false;
    }

    property bool recentlySaved: false
    // True once shell.json was read (or found missing) and migrated.
    property bool loaded: false

    ElapsedTimer {
        id: timer
    }

    Timer {
        id: saveTimer

        interval: 500
        onTriggered: {
            writeNow();
        }
    }

    Timer {
        id: recentSaveCooldown

        interval: 2000
        onTriggered: {
            recentlySaved = false;
        }
    }

    // One-shot data migration to Hornero Signal (RFC 0001). Rewrites
    // persisted values that name removed Material-era choices; it is not
    // an alias layer — once saved, the old values are gone.
    readonly property var _legacyThemeIds: ({
            "hornero-dark": "hornero-signal-night",
            "hornero-light": "hornero-signal-day",
            "hornero-199x": "hornero-signal-night",
            "neon-city": "hornero-signal-night",
            "vapor-dreams": "hornero-signal-night",
            "soft-morning": "hornero-signal-day",
            "warm-sunset": "hornero-signal-day"
        })
    readonly property var _legacyFontFamilies: ({
            "Rubik": "IBM Plex Sans",
            "CaskaydiaCove NF": "IBM Plex Mono"
        })

    function migrateLegacyAppearance(): bool {
        let changed = false;
        const theme = adapter.appearance.theme;
        if (_legacyThemeIds.hasOwnProperty(theme)) {
            adapter.appearance.theme = _legacyThemeIds[theme];
            changed = true;
        }
        const family = adapter.appearance.font.family;
        if (_legacyFontFamilies.hasOwnProperty(family.sans)) {
            family.sans = _legacyFontFamilies[family.sans];
            changed = true;
        }
        if (_legacyFontFamilies.hasOwnProperty(family.mono)) {
            family.mono = _legacyFontFamilies[family.mono];
            changed = true;
        }
        // Persisted Material-era icon names are not Hornero Glyphs:
        // fall back to the shipped default for that slot.
        const icons = adapter.session.icons;
        for (const key of ["logout", "shutdown", "hibernate", "reboot"]) {
            if (icons[key] && !Glyphs.has(icons[key])) {
                icons[key] = sessionDefaults.icons[key];
                changed = true;
            }
        }
        const levels = adapter.general.battery.warnLevels ?? [];
        const defaultLevels = generalDefaults.battery.warnLevels;
        let levelsChanged = false;
        const migratedLevels = levels.map((level, i) => {
            if (!level || !level.icon || Glyphs.has(level.icon))
                return level;
            levelsChanged = true;
            return Object.assign({}, level, {
                icon: defaultLevels[Math.min(i, defaultLevels.length - 1)]?.icon ?? "battery"
            });
        });
        if (levelsChanged) {
            adapter.general.battery.warnLevels = migratedLevels;
            changed = true;
        }
        const defaultActionIcons = {};
        for (const action of launcherDefaults.actions)
            defaultActionIcons[action.name] = action.icon;
        const actions = adapter.launcher.actions ?? [];
        const migrated = [];
        let actionsChanged = false;
        for (let action of actions) {
            if (action && action.icon && !Glyphs.has(action.icon)) {
                actionsChanged = true;
                action = Object.assign({}, action, {
                    icon: defaultActionIcons[action.name] ?? "terminal-2"
                });
            }
            const command = action?.command ?? [];
            if (command[0] === "autocomplete" && (command[1] === "scheme" || command[1] === "variant")) {
                actionsChanged = true;
                continue;
            }
            if (command[0] === "setMode") {
                actionsChanged = true;
                migrated.push(Object.assign({}, action, {
                    command: ["theme", command[1] === "light" ? "hornero-signal-day" : "hornero-signal-night"]
                }));
                continue;
            }
            migrated.push(action);
        }
        if (actionsChanged) {
            adapter.launcher.actions = migrated;
            changed = true;
        }
        return changed;
    }

    // One-shot: the retired Gaming Focus toast switch
    // (utilities.toasts.gameModeChanged) becomes experience.toasts. The
    // adapter ignores the old key, so it is read from the raw file and
    // dropped on the next save.
    function migrateLegacyExperience(raw: string): bool {
        let data;
        try {
            data = JSON.parse(raw);
        } catch (e) {
            return false;
        }
        const legacy = data?.utilities?.toasts?.gameModeChanged;
        if (typeof legacy !== "boolean")
            return false;
        if (data?.experience?.toasts === undefined)
            adapter.experience.toasts = legacy;
        return true;
    }

    // One-shot: `Config loaded` and `Num lock` toasts were on by default and
    // fire on every reload/boot (visual audit VA-15). Existing configs that
    // still carry them are switched off once; the marker keeps a later
    // opt-in from being reset.
    function migrateRoutineToasts(raw: string): bool {
        let data;
        try {
            data = JSON.parse(raw);
        } catch (e) {
            return false;
        }
        const toasts = data?.utilities?.toasts;
        if (toasts?.routineQuiet === true)
            return false;
        adapter.utilities.toasts.configLoaded = false;
        adapter.utilities.toasts.numLockChanged = false;
        adapter.utilities.toasts.routineQuiet = true;
        return true;
    }

    // Pristine compiled defaults for the migration above.
    SessionConfig {
        id: sessionDefaults
    }

    GeneralConfig {
        id: generalDefaults
    }

    LauncherConfig {
        id: launcherDefaults
    }

    // Helper function to serialize the config object
    function serializeConfig(): var {
        return {
            appearance: serializeAppearance(),
            general: serializeGeneral(),
            background: serializeBackground(),
            bar: serializeBar(),
            border: serializeBorder(),
            dashboard: serializeDashboard(),
            controlCenter: serializeControlCenter(),
            launcher: serializeLauncher(),
            notifs: serializeNotifs(),
            osd: serializeOsd(),
            session: serializeSession(),
            winfo: serializeWinfo(),
            lock: serializeLock(),
            utilities: serializeUtilities(),
            sounds: serializeSounds(),
            sidebar: serializeSidebar(),
            services: serializeServices(),
            paths: serializePaths(),
            plugins: serializePlugins(),
            experience: serializeExperience(),
            layouts: serializeLayouts()
        };
    }

    function serializeAppearance(): var {
        return {
            theme: appearance.theme,
            highContrast: appearance.highContrast,
            reducedMotion: appearance.reducedMotion,
            cozyChips: appearance.cozyChips,
            rounding: {
                scale: appearance.rounding.scale
            },
            spacing: {
                scale: appearance.spacing.scale
            },
            padding: {
                scale: appearance.padding.scale
            },
            font: {
                family: {
                    sans: appearance.font.family.sans,
                    mono: appearance.font.family.mono,
                    display: appearance.font.family.display
                },
                size: {
                    scale: appearance.font.size.scale
                },
                weight: {
                    shift: appearance.font.weight.shift
                }
            },
            anim: {
                mediaGifSpeedAdjustment: appearance.anim.mediaGifSpeedAdjustment,
                sessionGifSpeed: appearance.anim.sessionGifSpeed,
                curveStyle: appearance.anim.curveStyle,
                durations: {
                    scale: appearance.anim.durations.scale
                }
            },
            glow: {
                intensity: appearance.glow.intensity,
                limit: appearance.glow.limit
            },
            atmosphere: {
                enabled: appearance.atmosphere.enabled,
                lamp: appearance.atmosphere.lamp,
                warmth: appearance.atmosphere.warmth,
                innerLight: appearance.atmosphere.innerLight,
                vignette: appearance.atmosphere.vignette,
                grain: appearance.atmosphere.grain,
                scanlines: appearance.atmosphere.scanlines,
                plateTracking: appearance.atmosphere.plateTracking,
                mascot: appearance.atmosphere.mascot,
                tone: appearance.atmosphere.tone
            },
            transparency: {
                enabled: appearance.transparency.enabled,
                base: appearance.transparency.base,
                layers: appearance.transparency.layers,
                elements: appearance.transparency.elements
            },
            accent: {
                color: appearance.accent.color,
                perMode: {
                    dark: appearance.accent.perMode.dark,
                    light: appearance.accent.perMode.light
                },
                perExperience: appearance.accent.perExperience
            },
            chromatic: {
                source: appearance.chromatic.source,
                seeds: appearance.chromatic.seeds,
                variant: appearance.chromatic.variant,
                mode: appearance.chromatic.mode,
                contrast: appearance.chromatic.contrast,
                surfaceDepth: appearance.chromatic.surfaceDepth,
                chroma: appearance.chromatic.chroma,
                hueShift: appearance.chromatic.hueShift,
                follow: appearance.chromatic.follow,
                perMode: {
                    dark: {
                        variant: appearance.chromatic.perMode.dark.variant
                    },
                    light: {
                        variant: appearance.chromatic.perMode.light.variant
                    }
                },
                fallback: {
                    dark: appearance.chromatic.fallback.dark,
                    light: appearance.chromatic.fallback.light
                },
                transition: appearance.chromatic.transition
            }
        };
    }

    function serializeGeneral(): var {
        return {
            logo: general.logo,
            apps: {
                terminal: general.apps.terminal,
                audio: general.apps.audio,
                playback: general.apps.playback,
                explorer: general.apps.explorer
            },
            idle: {
                lockBeforeSleep: general.idle.lockBeforeSleep,
                inhibitWhenAudio: general.idle.inhibitWhenAudio,
                timeouts: general.idle.timeouts
            },
            battery: {
                warnLevels: general.battery.warnLevels,
                criticalLevel: general.battery.criticalLevel
            }
        };
    }

    function serializeBackground(): var {
        return {
            enabled: background.enabled,
            wallpaperEnabled: background.wallpaperEnabled,
            wallpaperFit: background.wallpaperFit,
            desktopClock: {
                enabled: background.desktopClock.enabled,
                scale: background.desktopClock.scale,
                position: background.desktopClock.position,
                invertColors: background.desktopClock.invertColors,
                background: {
                    enabled: background.desktopClock.background.enabled,
                    opacity: background.desktopClock.background.opacity,
                    blur: background.desktopClock.background.blur
                },
                shadow: {
                    enabled: background.desktopClock.shadow.enabled,
                    opacity: background.desktopClock.shadow.opacity,
                    blur: background.desktopClock.shadow.blur
                }
            },
            visualiser: {
                enabled: background.visualiser.enabled,
                autoHide: background.visualiser.autoHide,
                blur: background.visualiser.blur,
                rounding: background.visualiser.rounding,
                spacing: background.visualiser.spacing
            },
            video: {
                enabled: background.video.enabled,
                pauseOnFullscreen: background.video.pauseOnFullscreen,
                pauseOnGameMode: background.video.pauseOnGameMode,
                batteryLimitEnabled: background.video.batteryLimitEnabled,
                batteryLimit: background.video.batteryLimit
            }
        };
    }

    function serializeBar(): var {
        return {
            persistent: bar.persistent,
            showOnHover: bar.showOnHover,
            clearStyle: bar.clearStyle,
            clearInk: {
                strength: bar.clearInk.strength,
                outline: bar.clearInk.outline,
                polarity: bar.clearInk.polarity
            },
            typeface: bar.typeface,
            mark: bar.mark,
            dragThreshold: bar.dragThreshold,
            perScreen: bar.perScreen,
            bars: bar.bars,
            scrollActions: {
                workspaces: bar.scrollActions.workspaces,
                volume: bar.scrollActions.volume,
                brightness: bar.scrollActions.brightness
            },
            popouts: {
                activeWindow: bar.popouts.activeWindow,
                tray: bar.popouts.tray,
                statusIcons: bar.popouts.statusIcons
            },
            workspaces: {
                shown: bar.workspaces.shown,
                maxWindowIcons: bar.workspaces.maxWindowIcons,
                glyphScale: bar.workspaces.glyphScale,
                activeIndicator: bar.workspaces.activeIndicator,
                occupiedBg: bar.workspaces.occupiedBg,
                showWindows: bar.workspaces.showWindows,
                showWindowsOnSpecialWorkspaces: bar.workspaces.showWindowsOnSpecialWorkspaces,
                activeTrail: bar.workspaces.activeTrail,
                activeInset: bar.workspaces.activeInset,
                perMonitorWorkspaces: bar.workspaces.perMonitorWorkspaces,
                label: bar.workspaces.label,
                occupiedLabel: bar.workspaces.occupiedLabel,
                activeLabel: bar.workspaces.activeLabel,
                capitalisation: bar.workspaces.capitalisation,
                specialWorkspaceIcons: bar.workspaces.specialWorkspaceIcons
            },
            activeWindow: {
                inverted: bar.activeWindow.inverted
            },
            tray: {
                background: bar.tray.background,
                recolour: bar.tray.recolour,
                compact: bar.tray.compact,
                iconSubs: bar.tray.iconSubs,
                hiddenIcons: bar.tray.hiddenIcons
            },
            extensions: {
                background: bar.extensions.background,
                recolour: bar.extensions.recolour,
                compact: bar.extensions.compact,
                iconSubs: bar.extensions.iconSubs,
                hiddenIcons: bar.extensions.hiddenIcons,
                itemMaxWidth: bar.extensions.itemMaxWidth,
                sectionBudget: bar.extensions.sectionBudget,
                islandBudget: bar.extensions.islandBudget
            },
            status: {
                showAudio: bar.status.showAudio,
                showMicrophone: bar.status.showMicrophone,
                showKbLayout: bar.status.showKbLayout,
                showNetwork: bar.status.showNetwork,
                showWifi: bar.status.showWifi,
                showBluetooth: bar.status.showBluetooth,
                showBattery: bar.status.showBattery,
                showLockStatus: bar.status.showLockStatus
            },
            clock: {
                showIcon: bar.clock.showIcon,
                showDate: bar.clock.showDate,
                background: bar.clock.background
            },
            sizes: {
                innerWidth: bar.sizes.innerWidth,
                islandInset: bar.sizes.islandInset,
                autoDensity: bar.sizes.autoDensity,
                densityScale: bar.sizes.densityScale,
                contentScale: bar.sizes.contentScale,
                iconScale: bar.sizes.iconScale,
                textScale: bar.sizes.textScale,
                itemSpacing: bar.sizes.itemSpacing,
                textWeight: bar.sizes.textWeight,
                windowPreviewSize: bar.sizes.windowPreviewSize,
                trayMenuWidth: bar.sizes.trayMenuWidth,
                batteryWidth: bar.sizes.batteryWidth,
                networkWidth: bar.sizes.networkWidth,
                kbLayoutWidth: bar.sizes.kbLayoutWidth
            },
            excludedScreens: bar.excludedScreens
        };
    }

    function serializeBorder(): var {
        return {
            frameEnabled: border.frameEnabled,
            thickness: border.thickness,
            rounding: border.rounding,
            edgeWidth: border.edgeWidth
        };
    }

    function serializeDashboard(): var {
        return {
            enabled: dashboard.enabled,
            showOnHover: dashboard.showOnHover,
            composition: dashboard.composition,
            mediaUpdateInterval: dashboard.mediaUpdateInterval,
            resourceUpdateInterval: dashboard.resourceUpdateInterval,
            dragThreshold: dashboard.dragThreshold,
            performance: {
                showBattery: dashboard.performance.showBattery,
                showGpu: dashboard.performance.showGpu,
                showCpu: dashboard.performance.showCpu,
                showMemory: dashboard.performance.showMemory,
                showStorage: dashboard.performance.showStorage,
                showNetwork: dashboard.performance.showNetwork
            },
            workspaces: {
                showLivePreview: dashboard.workspaces.showLivePreview,
                showSpecialWorkspaces: dashboard.workspaces.showSpecialWorkspaces,
                showWindowBadges: dashboard.workspaces.showWindowBadges,
                showMonitorBadge: dashboard.workspaces.showMonitorBadge,
                maxAppIcons: dashboard.workspaces.maxAppIcons,
                previewHeight: dashboard.workspaces.previewHeight,
                enableWindowActions: dashboard.workspaces.enableWindowActions
            },
            media: {
                spectrum: dashboard.media.spectrum,
                peakHold: dashboard.media.peakHold,
                bands: dashboard.media.bands,
                javi: dashboard.media.javi
            },
            sizes: {
                tabIndicatorHeight: dashboard.sizes.tabIndicatorHeight,
                tabIndicatorSpacing: dashboard.sizes.tabIndicatorSpacing,
                infoWidth: dashboard.sizes.infoWidth,
                infoIconSize: dashboard.sizes.infoIconSize,
                dateTimeWidth: dashboard.sizes.dateTimeWidth,
                mediaWidth: dashboard.sizes.mediaWidth,
                mediaProgressSweep: dashboard.sizes.mediaProgressSweep,
                mediaProgressThickness: dashboard.sizes.mediaProgressThickness,
                resourceProgessThickness: dashboard.sizes.resourceProgessThickness,
                weatherWidth: dashboard.sizes.weatherWidth,
                mediaCoverArtSize: dashboard.sizes.mediaCoverArtSize,
                mediaVisualiserSize: dashboard.sizes.mediaVisualiserSize,
                resourceSize: dashboard.sizes.resourceSize
            }
        };
    }

    function serializeControlCenter(): var {
        return {
            sizes: {
                heightMult: controlCenter.sizes.heightMult,
                ratio: controlCenter.sizes.ratio
            },
            undoSeconds: controlCenter.undoSeconds,
            appearanceOpenSections: controlCenter.appearanceOpenSections
        };
    }

    function serializeLauncher(): var {
        return {
            enabled: launcher.enabled,
            showOnHover: launcher.showOnHover,
            align: launcher.align,
            maxShown: launcher.maxShown,
            maxWallpapers: launcher.maxWallpapers,
            specialPrefix: launcher.specialPrefix,
            actionPrefix: launcher.actionPrefix,
            enableDangerousActions: launcher.enableDangerousActions,
            dragThreshold: launcher.dragThreshold,
            vimKeybinds: launcher.vimKeybinds,
            favouriteApps: launcher.favouriteApps,
            hiddenApps: launcher.hiddenApps,
            useFuzzy: {
                apps: launcher.useFuzzy.apps,
                actions: launcher.useFuzzy.actions,
                wallpapers: launcher.useFuzzy.wallpapers
            },
            sizes: {
                itemWidth: launcher.sizes.itemWidth,
                itemHeight: launcher.sizes.itemHeight,
                wallpaperWidth: launcher.sizes.wallpaperWidth,
                wallpaperHeight: launcher.sizes.wallpaperHeight
            },
            actions: launcher.actions
        };
    }

    function serializeNotifs(): var {
        return {
            expire: notifs.expire,
            align: notifs.align,
            defaultExpireTimeout: notifs.defaultExpireTimeout,
            clearThreshold: notifs.clearThreshold,
            expandThreshold: notifs.expandThreshold,
            actionOnClick: notifs.actionOnClick,
            groupPreviewNum: notifs.groupPreviewNum,
            openExpanded: notifs.openExpanded,
            sizes: {
                width: notifs.sizes.width,
                image: notifs.sizes.image,
                badge: notifs.sizes.badge
            }
        };
    }

    function serializeOsd(): var {
        return {
            enabled: osd.enabled,
            hideDelay: osd.hideDelay,
            align: osd.align,
            enableBrightness: osd.enableBrightness,
            enableMicrophone: osd.enableMicrophone,
            sizes: {
                sliderWidth: osd.sizes.sliderWidth,
                sliderHeight: osd.sizes.sliderHeight
            }
        };
    }

    function serializeSession(): var {
        return {
            enabled: session.enabled,
            dragThreshold: session.dragThreshold,
            vimKeybinds: session.vimKeybinds,
            icons: {
                logout: session.icons.logout,
                shutdown: session.icons.shutdown,
                hibernate: session.icons.hibernate,
                reboot: session.icons.reboot
            },
            commands: {
                logout: session.commands.logout,
                shutdown: session.commands.shutdown,
                hibernate: session.commands.hibernate,
                reboot: session.commands.reboot
            },
            sizes: {
                button: session.sizes.button
            }
        };
    }

    function serializeWinfo(): var {
        return {
            sizes: {
                heightMult: winfo.sizes.heightMult,
                detailsWidth: winfo.sizes.detailsWidth
            }
        };
    }

    function serializeLock(): var {
        return {
            recolourLogo: lock.recolourLogo,
            hideNotifs: lock.hideNotifs,
            enableFprint: lock.enableFprint,
            maxFprintTries: lock.maxFprintTries,
            sizes: {
                heightMult: lock.sizes.heightMult,
                ratio: lock.sizes.ratio,
                centerWidth: lock.sizes.centerWidth
            }
        };
    }

    function serializeSounds(): var {
        return {
            enabled: sounds.enabled,
            volume: sounds.volume,
            theme: sounds.theme,
            alwaysChime: sounds.alwaysChime,
            events: {
                notification: sounds.events.notification,
                battery: sounds.events.battery,
                charger: sounds.events.charger
            }
        };
    }

    function serializeUtilities(): var {
        return {
            enabled: utilities.enabled,
            maxToasts: utilities.maxToasts,
            sizes: {
                width: utilities.sizes.width,
                toastWidth: utilities.sizes.toastWidth
            },
            toasts: {
                configLoaded: utilities.toasts.configLoaded,
                chargingChanged: utilities.toasts.chargingChanged,
                dndChanged: utilities.toasts.dndChanged,
                audioOutputChanged: utilities.toasts.audioOutputChanged,
                audioInputChanged: utilities.toasts.audioInputChanged,
                capsLockChanged: utilities.toasts.capsLockChanged,
                numLockChanged: utilities.toasts.numLockChanged,
                kbLayoutChanged: utilities.toasts.kbLayoutChanged,
                kbLimit: utilities.toasts.kbLimit,
                vpnChanged: utilities.toasts.vpnChanged,
                nowPlaying: utilities.toasts.nowPlaying,
                routineQuiet: utilities.toasts.routineQuiet
            },
            vpn: {
                enabled: utilities.vpn.enabled,
                provider: utilities.vpn.provider
            }
        };
    }

    function serializeSidebar(): var {
        return {
            enabled: sidebar.enabled,
            dragThreshold: sidebar.dragThreshold,
            sizes: {
                width: sidebar.sizes.width
            }
        };
    }

    function serializeServices(): var {
        return {
            weatherLocation: services.weatherLocation,
            useFahrenheit: services.useFahrenheit,
            useFahrenheitPerformance: services.useFahrenheitPerformance,
            useTwelveHourClock: services.useTwelveHourClock,
            gpuType: services.gpuType,
            visualiserBars: services.visualiserBars,
            audioIncrement: services.audioIncrement,
            brightnessIncrement: services.brightnessIncrement,
            maxVolume: services.maxVolume,
            smartScheme: services.smartScheme,
            defaultPlayer: services.defaultPlayer,
            playerAliases: services.playerAliases
        };
    }

    function serializePaths(): var {
        return {
            wallpaperDir: paths.wallpaperDir,
            sessionGif: paths.sessionGif,
            mediaGif: paths.mediaGif
        };
    }

    function serializePlugins(): var {
        return {
            settings: plugins.settings,
            instances: plugins.instances,
            quickTiles: plugins.quickTiles,
            desktopWidgetSlots: plugins.desktopWidgetSlots,
            desktopWidgets: plugins.desktopWidgets,
            dashboardLayout: plugins.dashboardLayout,
            safeMode: plugins.safeMode
        };
    }

    function serializeLayouts(): var {
        return {
            overrides: layouts.overrides
        };
    }

    function serializeExperience(): var {
        return {
            modes: experience.modes,
            toasts: experience.toasts,
            deck: experience.deck,
            auto: {
                fullscreenGaming: experience.auto.fullscreenGaming,
                gamePatterns: experience.auto.gamePatterns
            }
        };
    }

    // Runtime shell settings live at $XDG_CONFIG_HOME/hornero/shell.json.
    // A missing user file means compiled defaults apply (see onLoadFailed).
    FileView {
        id: fileView

        path: `${Paths.config}/shell.json`
        watchChanges: true
        onFileChanged: {
            // Prevent reload loop - don't reload if we just saved
            if (!recentlySaved) {
                timer.restart();
                reload();
            } else {
                // Self-initiated save - reload without toast
                reload();
            }
        }
        onLoaded: {
            const migratedAppearance = root.migrateLegacyAppearance();
            const migratedExperience = root.migrateLegacyExperience(text());
            const migratedToasts = root.migrateRoutineToasts(text());
            if (migratedAppearance || migratedExperience || migratedToasts)
                root.save();
            root.loaded = true;
            try {
                JSON.parse(text());
                const elapsed = timer.elapsedMs();
                // Only show toast for external changes (not our own saves) and when elapsed time is meaningful
                if (adapter.utilities.toasts.configLoaded && !recentlySaved && elapsed > 0) {
                    Toaster.toast(qsTr("Config loaded"), qsTr("Config loaded in %1ms").arg(elapsed), "settings-check");
                } else if (adapter.utilities.toasts.configLoaded && recentlySaved && elapsed > 0) {
                    Toaster.toast(qsTr("Config saved"), qsTr("Config reloaded in %1ms").arg(elapsed), "settings-check");
                }
            } catch (e) {
                Toaster.toast(qsTr("Failed to load config"), e.message, "settings-exclamation", Toast.Error);
            }
        }
        onLoadFailed: err => {
            root.loaded = true;
            if (err !== FileViewError.FileNotFound)
                Toaster.toast(qsTr("Failed to read config file"), FileViewError.toString(err), "settings-exclamation", Toast.Warning);
        }
        onSaveFailed: err => Toaster.toast(qsTr("Failed to save config"), FileViewError.toString(err), "settings-exclamation", Toast.Error)

        JsonAdapter {
            id: adapter

            property AppearanceConfig appearance: AppearanceConfig {}
            property GeneralConfig general: GeneralConfig {}
            property BackgroundConfig background: BackgroundConfig {}
            property BarConfig bar: BarConfig {}
            property BorderConfig border: BorderConfig {}
            property DashboardConfig dashboard: DashboardConfig {}
            property ControlCenterConfig controlCenter: ControlCenterConfig {}
            property LauncherConfig launcher: LauncherConfig {}
            property NotifsConfig notifs: NotifsConfig {}
            property OsdConfig osd: OsdConfig {}
            property SessionConfig session: SessionConfig {}
            property WInfoConfig winfo: WInfoConfig {}
            property LockConfig lock: LockConfig {}
            property UtilitiesConfig utilities: UtilitiesConfig {}
            property SoundsConfig sounds: SoundsConfig {}
            property SidebarConfig sidebar: SidebarConfig {}
            property ServiceConfig services: ServiceConfig {}
            property UserPaths paths: UserPaths {}
            property PluginsConfig plugins: PluginsConfig {}
            property ExperienceConfig experience: ExperienceConfig {}
            property LayoutsConfig layouts: LayoutsConfig {}
        }
    }

    // Kept outside FileView: its default property is the typed
    // `adapter`, so a bare Connections child fails config load on
    // current Quickshell ("Cannot assign ... FileViewAdapter*").
    Connections {
        target: adapter.plugins
        function onSaveRequested(): void {
            root.save();
        }
    }
}

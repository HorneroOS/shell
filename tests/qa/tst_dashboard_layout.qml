// Offscreen probe for the composable dashboard layout (shell#378).
// Exercises DashboardLayout directly (it has no shell singletons by
// design): responsive columns, size classes, pinned/category
// grouping, persisted ordering and keyboard reorder math, plus a
// 33-plugin stress fixture whose section computation must stay a
// single cheap pass. This is offscreen QML evidence only — no
// compositor, no AT-SPI, no real plugin Loader claim.
import QtQuick
import QtTest

Item {
    DashboardLayout {
        id: layout
    }

    TestCase {
        name: "DashboardLayout"

        function test_responsive_columns_and_spans() {
            compare(layout.columnsForWidth(0, 10), 1);
            compare(layout.columnsForWidth(300, 10), 1);
            compare(layout.columnsForWidth(560, 10), 2);
            compare(layout.columnsForWidth(840, 10), 3);
            compare(layout.columnsForWidth(1200, 10), 4);
            compare(layout.columnSpan("wide", 3), 2);
            compare(layout.columnSpan("wide", 1), 1);
            compare(layout.columnSpan("standard", 3), 1);
            compare(layout.contentWidth("standard"), 380);
            compare(layout.contentWidth("bogus"), 380);
            compare(layout.nextSize("compact"), "standard");
            compare(layout.nextSize("wide"), "compact");
        }

        function makePlugins(count) {
            const categories = ["System", "Media", "", "Network"];
            const sizes = ["compact", "standard", "wide"];
            const plugins = [];
            for (let i = 0; i < count; i++) {
                plugins.push({
                    id: "stress-" + (i < 10 ? "0" : "") + i,
                    name: "Stress " + (i < 10 ? "0" : "") + i,
                    cardSize: sizes[i % 3],
                    category: categories[i % 4]
                });
            }
            return plugins;
        }

        function test_grouping_pinning_and_order() {
            const plugins = makePlugins(8);
            const sections = layout.sectionsFor(plugins, {
                pinned: ["stress-03"],
                order: ["stress-05", "stress-01"],
                sizes: { "stress-01": "wide", "stress-02": "bogus" }
            });
            // Pinned first, categories alphabetical, uncategorized last.
            compare(sections[0].pinned, true);
            compare(sections[0].plugins[0].id, "stress-03");
            const named = sections.filter(s => !s.pinned && s.category !== "").map(s => s.category);
            compare(JSON.stringify(named), JSON.stringify(["Media", "Network", "System"]));
            compare(sections[sections.length - 1].category, "");
            // Persisted order wins inside its section; user size wins
            // over the manifest hint; a bogus stored size is dropped.
            const all = sections.reduce((acc, s) => acc.concat(s.plugins), []);
            compare(all.length, 8);
            const one = all.find(p => p.id === "stress-01");
            verify(one !== undefined);
            compare(one.sizeClass, "wide");
            const two = all.find(p => p.id === "stress-02");
            verify(two !== undefined);
            compare(two.sizeClass, "wide"); // manifest hint (2 % 3), bogus override ignored
            const media = sections.find(s => s.category === "Media");
            verify(media !== undefined);
            compare(media.plugins[0].id, "stress-05"); // explicit order first
            compare(media.plugins[1].id, "stress-01");
        }

        function test_malformed_layout_degrades_to_defaults() {
            const sections = layout.sectionsFor(makePlugins(4), "junk");
            compare(sections.reduce((n, s) => n + s.plugins.length, 0), 4);
            compare(layout.sectionsFor(undefined, undefined).length, 0);
            compare(layout.sectionsFor([{ id: "" }, { name: "no id" }], {}).length, 0);
        }

        function test_keyboard_reorder_math() {
            const visible = ["a", "b", "c", "d"];
            // First move seeds order from what is visible, never jumps.
            compare(JSON.stringify(layout.movedOrder([], visible, "b", 1)), JSON.stringify(["a", "c", "b", "d"]));
            compare(JSON.stringify(layout.movedOrder(["a", "b", "c", "d"], visible, "a", -1)), JSON.stringify(["a", "b", "c", "d"]));
            compare(JSON.stringify(layout.movedOrder(["a", "b", "c", "d"], visible, "missing", 1)), JSON.stringify(["a", "b", "c", "d"]));
        }

        function test_stress_33_plugins_single_pass() {
            const plugins = makePlugins(33);
            const started = Date.now();
            let sections = [];
            for (let round = 0; round < 20; round++)
                sections = layout.sectionsFor(plugins, { pinned: ["stress-00"], order: [], sizes: {} });
            const elapsed = Date.now() - started;
            compare(sections.reduce((n, s) => n + s.plugins.length, 0), 33);
            compare(sections[0].plugins.length >= 1 && sections[0].pinned, true);
            // Generous bound: 20 full computations over 33 plugins is
            // a fraction of this on any test host; the assertion only
            // catches pathological (per-card quadratic) blow-ups.
            verify(elapsed < 5000, "33-plugin layout too slow: " + elapsed + "ms for 20 rounds");
        }
    }
}

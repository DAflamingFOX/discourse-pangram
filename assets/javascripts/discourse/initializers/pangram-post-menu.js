import { withPluginApi } from "discourse/lib/plugin-api";
import PangramScanButton from "../components/pangram-scan-button";

export default {
  name: "pangram-post-menu",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings?.pangram_enabled) {
      return;
    }

    withPluginApi((api) => {
      const currentUser = api.getCurrentUser();
      if (!currentUser?.staff) {
        return;
      }

      api.addTrackedPostProperties(
        "pangram_ai_fraction",
        "pangram_ai_assisted_fraction",
        "pangram_human_fraction",
        "pangram_checked_at",
        "pangram_scanned_version",
        "pangram_history"
      );

      if (api.registerValueTransformer) {
        api.registerValueTransformer(
          "post-menu-buttons",
          ({
            value: dag,
            context: { lastHiddenButtonKey, secondLastHiddenButtonKey },
          }) => {
            dag.add("pangram-scan", PangramScanButton, {
              before: lastHiddenButtonKey,
              after: secondLastHiddenButtonKey,
            });
          }
        );
      }
    });
  },
};

import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class PangramScanButton extends Component {
  static hidden(args, context) {
    if (!context.currentUser?.staff || !context.siteSettings?.pangram_enabled) {
      return true;
    }
    return false;
  }

  @service toasts;
  @service messageBus;

  @tracked scanning = false;

  get isAlreadyScanned() {
    return (
      this.post?.pangram_ai_fraction !== undefined &&
      this.post?.pangram_ai_fraction !== null &&
      this.post?.pangram_scanned_version === this.post?.version
    );
  }

  get buttonTitle() {
    if (this.isAlreadyScanned) {
      return "pangram.already_scanned_title";
    }
    return "pangram.scan_action_title";
  }

  get post() {
    return this.args.post;
  }

  @action
  async scan() {
    const post = this.post;
    console.log("PANGRAM: Button clicked for post", post?.id);

    if (!post?.id || this.scanning) {
      console.log("PANGRAM: Aborting due to no post id or already scanning");
      return;
    }

    if (this.isAlreadyScanned) {
      console.log("PANGRAM: Already scanned");
      if (this.toasts?.info) {
        this.toasts.info({ data: { message: i18n("pangram.already_scanned") } });
      }
      return;
    }

    this.scanning = true;

    if (this.toasts?.info) {
      this.toasts.info({ data: { message: i18n("pangram.scanning") } });
    }

    const channel = `/pangram/posts/${post.id}`;
    if (this.messageBus?.subscribe) {
      this.messageBus.subscribe(channel, (data) => {
        console.log("PANGRAM: Received message bus data", data);
        if (data?.post_id === post.id) {
          post.setProperties({
            pangram_ai_fraction: data.ai_fraction,
            pangram_ai_assisted_fraction: data.ai_assisted_fraction,
            pangram_human_fraction: data.human_fraction,
            pangram_checked_at: data.checked_at,
            pangram_scanned_version: data.scanned_version || post.version,
          });

          if (this.toasts?.success) {
            this.toasts.success({
              data: { message: i18n("pangram.scan_completed") },
            });
          }

          this.messageBus.unsubscribe(channel);
          this.scanning = false;
        }
      });
    }

    try {
      const url = `/pangram/posts/${post.id}/scan`;
      console.log("PANGRAM: Calling ajax URL:", url);
      const response = await ajax(url, {
        type: "POST",
      });
      console.log("PANGRAM: Ajax response:", response);

      if (response?.ai_fraction !== undefined) {
        post.setProperties({
          pangram_ai_fraction: response.ai_fraction,
          pangram_ai_assisted_fraction: response.ai_assisted_fraction,
          pangram_human_fraction: response.human_fraction,
          pangram_checked_at: response.checked_at,
          pangram_scanned_version: response.scanned_version || post.version,
        });

        if (this.toasts?.success) {
          this.toasts.success({ data: { message: i18n("pangram.scan_completed") } });
        }
      } else if (response?.cached) {
        if (this.toasts?.info) {
          this.toasts.info({ data: { message: i18n("pangram.already_scanned") } });
        }
      }
    } catch (error) {
      console.error("PANGRAM: Ajax error:", error);
      popupAjaxError(error);
    } finally {
      console.log("PANGRAM: Resetting scanning state");
      this.scanning = false;
    }
  }

  <template>
    <DButton
      class="post-action-menu__pangram-scan"
      ...attributes
      @action={{this.scan}}
      @disabled={{this.scanning}}
      @icon={{if this.isAlreadyScanned "check" "robot"}}
      @title={{this.buttonTitle}}
      @label="pangram.scan_action"
    />
  </template>
}

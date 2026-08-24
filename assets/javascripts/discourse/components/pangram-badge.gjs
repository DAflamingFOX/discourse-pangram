import Component from "@glimmer/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class PangramBadge extends Component {
  get post() {
    return this.args.post;
  }

  get aiFraction() {
    return this.post?.pangram_ai_fraction;
  }

  get aiAssistedFraction() {
    return this.post?.pangram_ai_assisted_fraction;
  }

  get humanFraction() {
    return this.post?.pangram_human_fraction;
  }

  get isVisible() {
    return this.aiFraction !== undefined && this.aiFraction !== null;
  }

  get aiPercentage() {
    return Math.round((this.aiFraction || 0) * 100);
  }

  get aiAssistedPercentage() {
    return Math.round((this.aiAssistedFraction || 0) * 100);
  }

  get humanPercentage() {
    return Math.round((this.humanFraction || 0) * 100);
  }

  get severityClass() {
    const pct = this.aiPercentage;
    if (pct >= 70) {
      return "pangram-badge--high";
    } else if (pct >= 35) {
      return "pangram-badge--medium";
    }
    return "pangram-badge--low";
  }

  get tooltipText() {
    return `${i18n("pangram.badge_title")}: ${this.aiPercentage}% ${i18n("pangram.ai_fraction")}, ${this.aiAssistedPercentage}% ${i18n("pangram.ai_assisted_fraction")}, ${this.humanPercentage}% ${i18n("pangram.human_fraction")}`;
  }

  <template>
    {{#if this.isVisible}}
      <div
        class="pangram-badge {{this.severityClass}}"
        title={{this.tooltipText}}
      >
        <span class="pangram-badge__icon">
          {{dIcon "robot"}}
        </span>
        <span class="pangram-badge__label">
          {{i18n "pangram.score_label" percentage=this.aiPercentage}}
        </span>
      </div>
    {{/if}}
  </template>
}

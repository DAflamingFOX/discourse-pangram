import PangramBadge from "../../components/pangram-badge";

export default <template>
  <PangramBadge @post={{@outletArgs.post}} />
  {{yield}}
</template>

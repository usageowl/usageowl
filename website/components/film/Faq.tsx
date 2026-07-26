import Eyebrow from './Eyebrow';
import FaqAccordion from './FaqAccordion';
import { FAQ } from '../content';

/**
 * FAQ — eyebrow + keyboard-accessible accordion.
 */
export default function Faq() {
  return (
    <section id="faq" aria-labelledby="ax-faq" className="scroll-mt-24">
      <div className="mx-auto max-w-6xl px-5 py-24 sm:px-8">
        <Eyebrow n="04" label="faq" note={String(FAQ.length).padStart(2, '0')} />
        <FaqAccordion />
      </div>
    </section>
  );
}

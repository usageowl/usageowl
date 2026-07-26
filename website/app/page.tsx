import SiteNav from '@/components/film/SiteNav';
import Loader from '@/components/film/Loader';
import Hero from '@/components/film/Hero';
import Providers from '@/components/film/Providers';
import Thresholds from '@/components/film/Thresholds';
import Features from '@/components/film/Features';
import OwlIndex from '@/components/film/OwlIndex';
import Privacy from '@/components/film/Privacy';
import Climax from '@/components/film/Climax';
import Faq from '@/components/film/Faq';
import Footer from '@/components/film/Footer';

export default function Home() {
  return (
    <>
      <a href="#providers" className="skip-link">
        Skip to content
      </a>
      <Loader />
      <SiteNav />
      <main id="main">
        {/* static hero — the download CTA leads */}
        <Hero />
        <Providers />
        {/* film 1: the threshold count */}
        <Thresholds />
        <Features />
        {/* film 2: the spec index, aligned on the O's axis */}
        <OwlIndex />
        <Privacy />
        {/* film 3: the 90% alert, architectural */}
        <Climax />
        <Faq />
      </main>
      <Footer />
    </>
  );
}

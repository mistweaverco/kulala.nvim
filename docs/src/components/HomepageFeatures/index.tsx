import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  description: JSX.Element;
};

const FeatureList: FeatureItem[] = [
  {
    title: 'Easy to Use',
    description: (
      <>
        <p>
          A minimal REST-Client Interface for Neovim.
        </p>

        <p>
          Kulala is swahili for "rest" or "relax".
        </p>

        <p>
          It allows you to make HTTP requests from within Neovim.
        </p>

        <img src="https://github.com/mistweaverco/kulala.nvim/assets/1384938/d3b1e6a6-b91d-4572-a4f0-8a9aa26696d9" alt="Kulala.nvim in action gif" />
      </>
    ),
  },
];

function Feature({title, description}: FeatureItem) {
  return (
    <div className={clsx('col')}>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <div>{description}</div>
      </div>
    </div>
  );
}

export default function HomepageFeatures(): JSX.Element {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}

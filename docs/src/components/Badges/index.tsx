import clsx from 'clsx';
import styles from './styles.module.css';

type BadgeItem = {
  imgUrl: string
  altTag: string;
  url?: string;
};

const BadgeList: BadgeItem[] = [
  {
    imgUrl: 'https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua',
    altTag: 'Made with Lua',
  },
  {
    imgUrl: 'https://img.shields.io/github/v/release/mistweaverco/kulala.nvim?style=for-the-badge',
    altTag: 'GitHub release (latest by date)',
    url: 'https://github.com/mistweaverco/kulala.nvim/releases/latest',
  },
  {
    imgUrl: 'https://img.shields.io/badge/discord-join-7289da?style=for-the-badge&logo=discord',
    altTag: 'Discord',
    url: 'https://discord.gg/QyVQmfY4Rt',
  },
];

function Badge({imgUrl, altTag, url}: BadgeItem) {
  return (
    <div className={styles.badge}>
        {
          url ? (
            <a href={url}>
              <img src={imgUrl} alt={altTag} />
            </a>
          ) : (
            <img src={imgUrl} alt={altTag} />
          )
        }
    </div>
  );
}

export default function Badges(): JSX.Element {
  return (
    <section className={styles.badges}>
      <div className="container">
        <div className="text--center padding-horiz--md">
          {BadgeList.map((props, idx) => (
            <Badge key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}

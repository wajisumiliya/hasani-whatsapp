const links=[['Dashboard','/'],['Customers','/customers'],['Templates','/templates'],['Campaigns','/campaigns'],['Reports','/reports']];
export default function Nav(){return <nav className="nav"><div className="brand"><b>hasani</b><strong>BOOKS</strong></div><div className="navlinks">{links.map(([n,h])=><a key={h} href={h}>{n}</a>)}</div></nav>}

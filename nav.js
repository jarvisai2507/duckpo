/* duckpo 공용 네비게이션 (2026-08-05 신설)
 * 페이지 목록을 이 배열 하나로 관리한다 — 새 페이지를 추가할 때 각 파일의
 * <nav>를 일일이 고칠 필요 없이 여기 한 줄만 추가하면 전 페이지에 반영된다.
 * <nav id="siteNav"></nav> 를 둔 페이지에서 자동으로 채워진다.
 */
(function () {
  const PAGES = [
    { href: 'index.html', icon: '📋', label: '게시판' },
    { href: 'org.html', icon: '🏛️', label: '조직도' },
    { href: '상황판.html', icon: '🧭', label: '상황판' },
    { href: '타임라인.html', icon: '🗓️', label: '타임라인' },
  ];

  function currentFile() {
    const path = decodeURIComponent(location.pathname);
    const file = path.substring(path.lastIndexOf('/') + 1);
    return file || 'index.html';
  }

  function render() {
    const nav = document.getElementById('siteNav');
    if (!nav) return;
    const cur = currentFile();
    const links = PAGES.map(p => {
      const cls = p.href === cur ? ' class="active"' : '';
      return `<a href="${p.href}"${cls}>${p.icon} ${p.label}</a>`;
    }).join('');
    nav.innerHTML = links + '<button class="logout-btn" onclick="duckpo.logout()">로그아웃</button>';
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', render);
  } else {
    render();
  }
})();

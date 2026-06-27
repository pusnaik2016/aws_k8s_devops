// ==============================================================================
// Nav Component — Netflix-style sticky navigation bar
// ==============================================================================
// Transparent on page load, transitions to dark background on scroll.
// ==============================================================================
import React, { useEffect, useState } from "react";

function Nav() {
  const [show, setShow] = useState(false);

  useEffect(() => {
    const handleScroll = () => {
      setShow(window.scrollY > 100);
    };

    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <nav className={`nav ${show ? "nav__black" : ""}`}>
      <span className="nav__logo">NETFLIX</span>

      <ul className="nav__links">
        <li>
          <span className="nav__link">Home</span>
        </li>
        <li>
          <span className="nav__link">TV Shows</span>
        </li>
        <li>
          <span className="nav__link">Movies</span>
        </li>
        <li>
          <span className="nav__link">New &amp; Popular</span>
        </li>
        <li>
          <div className="nav__avatar">U</div>
        </li>
      </ul>
    </nav>
  );
}

export default Nav;

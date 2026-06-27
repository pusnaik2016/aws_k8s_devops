// ==============================================================================
// App.js — Netflix Clone Main Application
// ==============================================================================
// Renders the Netflix-style layout with navigation, hero banner,
// and multiple movie category rows fetched from the TMDB API.
// ==============================================================================
import React from "react";
import "./App.css";
import Nav from "./components/Nav";
import Banner from "./components/Banner";
import Row from "./components/Row";
import requests from "./api/requests";

function App() {
  return (
    <div className="app">
      <Nav />
      <Banner />

      {/* Movie Category Rows */}
      <div className="app__rows">
        <Row
          title="NETFLIX ORIGINALS"
          fetchUrl={requests.fetchNetflixOriginals}
          isLargeRow
        />
        <Row title="Trending Now" fetchUrl={requests.fetchTrending} />
        <Row title="Top Rated" fetchUrl={requests.fetchTopRated} />
        <Row title="Action Movies" fetchUrl={requests.fetchActionMovies} />
        <Row title="Comedy Movies" fetchUrl={requests.fetchComedyMovies} />
        <Row title="Horror Movies" fetchUrl={requests.fetchHorrorMovies} />
        <Row title="Romance Movies" fetchUrl={requests.fetchRomanceMovies} />
        <Row title="Documentaries" fetchUrl={requests.fetchDocumentaries} />
      </div>

      {/* Footer */}
      <footer className="app__footer">
        <p>
          🎬 Netflix Clone — DevSecOps Demo |{" "}
          <span className="app__footer-highlight">
            Deployed with GitHub Actions + ArgoCD on AWS EKS
          </span>
        </p>
        <p className="app__footer-sub">
          Powered by TMDB API • Not affiliated with Netflix
        </p>
      </footer>
    </div>
  );
}

export default App;

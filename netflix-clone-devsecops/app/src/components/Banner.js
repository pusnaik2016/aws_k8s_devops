// ==============================================================================
// Banner Component — Hero section with random Netflix Original
// ==============================================================================
// Fetches Netflix Originals from TMDB and displays a random one as the
// hero banner with backdrop image, title, description, and action buttons.
// ==============================================================================
import React, { useEffect, useState } from "react";
import axios from "../api/axios";
import requests from "../api/requests";

const IMAGE_BASE_URL = "https://image.tmdb.org/t/p/original/";

function Banner() {
  const [movie, setMovie] = useState(null);

  useEffect(() => {
    async function fetchData() {
      try {
        const response = await axios.get(requests.fetchNetflixOriginals);
        const results = response.data.results;
        setMovie(results[Math.floor(Math.random() * results.length)]);
      } catch (error) {
        console.error("Failed to fetch banner data:", error);
      }
    }
    fetchData();
  }, []);

  if (!movie) return null;

  // Truncate description to avoid overflow
  const truncate = (str, n) =>
    str?.length > n ? str.substring(0, n - 1) + "..." : str;

  return (
    <header
      className="banner"
      style={{
        backgroundImage: `url("${IMAGE_BASE_URL}${
          movie?.backdrop_path || ""
        }")`,
      }}
    >
      <div className="banner__contents">
        <h1 className="banner__title">
          {movie?.title || movie?.name || movie?.original_name}
        </h1>

        <p className="banner__description">
          {truncate(movie?.overview, 200)}
        </p>

        <div className="banner__buttons">
          <button className="banner__button banner__button--play">
            ▶ Play
          </button>
          <button className="banner__button banner__button--info">
            ℹ More Info
          </button>
        </div>
      </div>

      <div className="banner--fadeBottom" />
    </header>
  );
}

export default Banner;

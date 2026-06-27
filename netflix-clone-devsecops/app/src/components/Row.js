// ==============================================================================
// Row Component — Horizontal scrollable movie/TV show row
// ==============================================================================
// Fetches a category of movies/TV shows from TMDB and renders them as
// horizontally scrollable poster images. Clicking a poster opens a
// YouTube trailer embed (via the movie-trailer package).
// ==============================================================================
import React, { useEffect, useState } from "react";
import axios from "../api/axios";
import YouTube from "react-youtube";
import movieTrailer from "movie-trailer";

const IMAGE_BASE_URL = "https://image.tmdb.org/t/p/";
const POSTER_SIZE = "w500";
const BACKDROP_SIZE = "w300";

function Row({ title, fetchUrl, isLargeRow }) {
  const [movies, setMovies] = useState([]);
  const [trailerUrl, setTrailerUrl] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function fetchData() {
      try {
        const response = await axios.get(fetchUrl);
        setMovies(response.data.results);
      } catch (error) {
        console.error(`Failed to fetch ${title}:`, error);
      } finally {
        setLoading(false);
      }
    }
    fetchData();
  }, [fetchUrl, title]);

  const opts = {
    height: "390",
    width: "100%",
    playerVars: {
      autoplay: 1,
    },
  };

  const handleClick = (movie) => {
    if (trailerUrl) {
      setTrailerUrl("");
    } else {
      movieTrailer(movie?.name || movie?.title || "")
        .then((url) => {
          if (url) {
            const urlParams = new URLSearchParams(new URL(url).search);
            setTrailerUrl(urlParams.get("v"));
          }
        })
        .catch(() => {
          // Silently fail if no trailer found
        });
    }
  };

  // Shimmer loading skeleton
  if (loading) {
    return (
      <div className="row">
        <h2 className="row__title">{title}</h2>
        <div className="row__loading">
          {Array.from({ length: 8 }).map((_, i) => (
            <div
              key={i}
              className={`row__loading-card ${
                isLargeRow ? "row__loading-card--large" : ""
              }`}
            />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="row">
      <h2 className="row__title">{title}</h2>

      <div className="row__posters">
        {movies.map((movie) => {
          const imagePath = isLargeRow
            ? movie.poster_path
            : movie.backdrop_path;

          if (!imagePath) return null;

          return (
            <img
              key={movie.id}
              className={`row__poster ${isLargeRow ? "row__posterLarge" : ""}`}
              src={`${IMAGE_BASE_URL}${
                isLargeRow ? POSTER_SIZE : BACKDROP_SIZE
              }${imagePath}`}
              alt={movie.name || movie.title}
              onClick={() => handleClick(movie)}
              loading="lazy"
            />
          );
        })}
      </div>

      {trailerUrl && (
        <div className="row__trailer">
          <YouTube videoId={trailerUrl} opts={opts} />
        </div>
      )}
    </div>
  );
}

export default Row;

import React, { useEffect, useMemo, useState } from "react";
import UserRow from "./UserRow";
import Glow from "./Glow";
import {
  cardStyle,
  emptyStateStyle,
  errorStateStyle,
  inputStyle,
  pageButtonStyle,
  pageIndicatorStyle,
  sectionSubtextStyle,
  sectionTitleStyle,
} from "../styles/portalStyles";
import {
  formatCreatedAt,
  getDisplayName,
  getInitials,
  normalizeStatus,
} from "../utils/portalFormatters";

const USERS_PER_PAGE = 25;

export default function UsersPanel({
  users,
  usersLoading,
  usersError,
  usersTableRef,
  onSelectUser,
}) {
  const [search, setSearch] = useState("");
  const [statusFilter, setStatusFilter] = useState("All");
  const [currentPage, setCurrentPage] = useState(1);

  const filteredUsers = useMemo(() => {
    return users.filter((user) => {
      const fullName = `${user.first_name || ""} ${user.last_name || ""}`.trim();
      const email = user.email || "";
      const role = user.role || "";
      const normalizedStatus =
        String(user.status || "").toLowerCase() === "active" ? "Active" : "Inactive";

      const matchesSearch =
        fullName.toLowerCase().includes(search.toLowerCase()) ||
        email.toLowerCase().includes(search.toLowerCase()) ||
        role.toLowerCase().includes(search.toLowerCase());

      const matchesStatus =
        statusFilter === "All" ? true : normalizedStatus === statusFilter;

      return matchesSearch && matchesStatus;
    });
  }, [users, search, statusFilter]);

  const totalPages = Math.max(1, Math.ceil(filteredUsers.length / USERS_PER_PAGE));

  const paginatedUsers = useMemo(() => {
    const startIndex = (currentPage - 1) * USERS_PER_PAGE;
    return filteredUsers.slice(startIndex, startIndex + USERS_PER_PAGE);
  }, [filteredUsers, currentPage]);

  useEffect(() => {
    setCurrentPage(1);
  }, [search, statusFilter]);

  useEffect(() => {
    if (currentPage > totalPages) {
      setCurrentPage(totalPages);
    }
  }, [currentPage, totalPages]);

  const firstUserIndex =
    filteredUsers.length === 0 ? 0 : (currentPage - 1) * USERS_PER_PAGE + 1;

  const lastUserIndex = Math.min(currentPage * USERS_PER_PAGE, filteredUsers.length);

  return (
    <>
      <section
        style={{
          ...cardStyle,
          display: "grid",
          gap: 16,
        }}
      >
        <div>
          <h2 style={sectionTitleStyle}>Filters</h2>
          <p style={sectionSubtextStyle}>Search and narrow the users list</p>
        </div>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "minmax(0, 1.4fr) minmax(180px, 220px)",
            gap: 14,
          }}
        >
          <input
            type="text"
            placeholder="Search by name, email, or role..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={inputStyle}
          />

          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            style={inputStyle}
          >
            <option value="All">All Statuses</option>
            <option value="Active">Active Only</option>
            <option value="Inactive">Inactive Only</option>
          </select>
        </div>
      </section>

      <section
        ref={usersTableRef}
        style={{
          ...cardStyle,

          // This makes scrollIntoView({ block: "start" }) align nicely
          // instead of crushing the Users table against the very top.
          scrollMarginTop: 20,
        }}
      >
        <Glow color="rgba(34,211,238,0.12)" />

        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            gap: 14,
            flexWrap: "wrap",
            marginBottom: 18,
          }}
        >
          <div>
            <h2 style={sectionTitleStyle}>Users</h2>
            <p style={sectionSubtextStyle}>
              Showing {firstUserIndex}-{lastUserIndex} of {filteredUsers.length} users
            </p>
          </div>

          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 10,
            }}
          >
            <button
              type="button"
              onClick={() => setCurrentPage((prev) => Math.max(1, prev - 1))}
              disabled={currentPage === 1}
              style={{
                ...pageButtonStyle,
                opacity: currentPage === 1 ? 0.45 : 1,
                cursor: currentPage === 1 ? "not-allowed" : "pointer",
              }}
            >
              ←
            </button>

            <div style={pageIndicatorStyle}>
              Page {currentPage} of {totalPages}
            </div>

            <button
              type="button"
              onClick={() => setCurrentPage((prev) => Math.min(totalPages, prev + 1))}
              disabled={currentPage === totalPages}
              style={{
                ...pageButtonStyle,
                opacity: currentPage === totalPages ? 0.45 : 1,
                cursor: currentPage === totalPages ? "not-allowed" : "pointer",
              }}
            >
              →
            </button>
          </div>
        </div>

        {usersLoading ? (
          <div style={emptyStateStyle}>Loading users...</div>
        ) : usersError ? (
          <div style={errorStateStyle}>{usersError}</div>
        ) : paginatedUsers.length > 0 ? (
          <div style={{ display: "grid", gap: 12 }}>
            {paginatedUsers.map((user) => (
              <UserRow
                key={user.id}
                initials={getInitials(user)}
                name={getDisplayName(user)}
                email={user.email}
                role={user.role || "user"}
                status={normalizeStatus(user.status)}
                createdAt={formatCreatedAt(user.created_at)}
                onClick={() => onSelectUser(user.id)}
              />
            ))}
          </div>
        ) : (
          <div style={emptyStateStyle}>No users match your current filters.</div>
        )}
      </section>
    </>
  );
}
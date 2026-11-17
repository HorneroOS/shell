// SPDX-License-Identifier: GPL-3.0-only
// Hornero Chromatic — result type (C++20 stand-in for std::expected).
#pragma once

#include <QString>

#include <utility>
#include <variant>

namespace hornero::chromatic {

struct Error {
    // Values are the helper's process exit codes (RFC 0002 §10.1).
    enum Code { Usage = 2, SourceUnreadable = 3, GatesUnreachable = 4, Internal = 5 };
    Code code = Internal;
    QString message;

    // Stable machine names: "usage", "source-unreadable", "gates-unreachable", "internal".
    [[nodiscard]] QString codeName() const;
};

template <typename T> class Expected {
public:
    Expected(T value)
        : m_value(std::move(value)) {}
    Expected(Error error)
        : m_value(std::move(error)) {}

    [[nodiscard]] bool ok() const noexcept { return std::holds_alternative<T>(m_value); }
    explicit operator bool() const noexcept { return ok(); }

    [[nodiscard]] T& value() & { return std::get<T>(m_value); }
    [[nodiscard]] const T& value() const& { return std::get<T>(m_value); }
    [[nodiscard]] T&& value() && { return std::get<T>(std::move(m_value)); }
    [[nodiscard]] const Error& error() const { return std::get<Error>(m_value); }

    T* operator->() { return &std::get<T>(m_value); }
    const T* operator->() const { return &std::get<T>(m_value); }

private:
    std::variant<T, Error> m_value;
};

} // namespace hornero::chromatic
